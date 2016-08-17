
CVS_REPOSITORY_DIR=/home/cvs/cvs2git/cvsroot-netbsd
CVS_MODULE=src

CVS=cvs
GIT=git
MKDIR=mkdir -p
PERL=perl
RM=rm -f

WORKDIR1=work.import
WORKDIR2=work.increment
GITDIR=gitwork
CVSTMPDIR=cvstmp
TMPDIR=/var/tmp

RSYNC_PROXY=your.proxyserver.local:8080

usage:
	@echo "Usage: make <target>"


import:
	${MAKE} import0
	${MAKE} import1

import0:
	${MAKE} get-cvsrepository
	${MAKE} makeworkdir1
	${MAKE} jslog
	${MAKE} branchinfo

import1:
	${MAKE} cvscheckout
	${MAKE} creategitimport
	${MAKE} gitinit
	${MAKE} gitimport
	${MAKE} gitreset

force-update:
	${MAKE} get-cvsrepository
	${MAKE} update-sync
	${MAKE} repository-analyze
	${MAKE} cvsupdate
	${MAKE} update-commit2
	${MAKE} compare-dir

update:
	${MAKE} get-cvsrepository
	${MAKE} update-sametime
	${MAKE} compare-dir-hack
	${MAKE} repository-analyze
	${MAKE} cvsupdate
	${MAKE} git-checkout-master
	${MAKE} update-commit2
	${MAKE} compare-dir
	${MAKE} push

#
#
#

update-sync:
	@if [ ! -d ${CVS_REPOSITORY_DIR} ] ; then	\
		${MAKE} cvscheckout;			\
	fi
	${MAKE} sync-cvs-sametime-git
	${MAKE} copy-from-cvs-to-git-and-commit

update-sametime:
	@if [ ! -d ${CVS_REPOSITORY_DIR} ] ; then	\
		${MAKE} cvscheckout;			\
	fi
	${MAKE} sync-cvs-sametime-git

repository-analyze:
	${MAKE} makeworkdir2
	${GIT} --git-dir=${GITDIR}/.git show --format='%at' | head -1 > ${WORKDIR2}/timestamp.git
	${PERL} -e '$$t = shift; utime $$t - 1, $$t - 1, shift' `cat ${WORKDIR2}/timestamp.git` ${WORKDIR2}/timestamp.git
	(here=`pwd`; cd ${CVS_REPOSITORY_DIR}/${CVS_MODULE} && find . -type f -newer $$here/${WORKDIR2}/timestamp.git -name '*,v' -print0 | xargs -0 -n5000 $$here/rcs2js) > ${WORKDIR2}/log
#	(here=`pwd`; cd ${CVS_REPOSITORY_DIR}/${CVS_MODULE} && find . -type f -name '*,v' -print0 | xargs -0 -n5000 $$here/rcs2js) > ${WORKDIR2}/log
	env TMPDIR=/var/tmp sort ${WORKDIR2}/log > ${WORKDIR2}/log.sorted
	${RM} -- ${WORKDIR2}/log
	./js2jslog_branch -t `cat ${WORKDIR2}/timestamp.git` -d ${WORKDIR2} ${WORKDIR2}/log.sorted

update-commit2:
	./jslog2gitappendcommit ${WORKDIR2}/commit.#trunk.jslog '#trunk' ${GITDIR} ${CVSTMPDIR}

update-commit-force:
	./jslog2gitappendcommit -f ${WORKDIR2}/commit.#trunk.jslog '#trunk' ${GITDIR} ${CVSTMPDIR}

distclean:
	${RM} -r -- ${WORKDIR1} ${WORKDIR2} ${GITDIR} ${CVSTMPDIR}

sync-cvs-sametime-git:
	echo "`${GIT} --git-dir=${GITDIR}/.git show --format='%ai' | head -1`" > GITTIME
	${RM} -r -- ${CVSTMPDIR} && env TZ=UTC ${CVS} -d ${CVS_REPOSITORY_DIR} co -D"`${GIT} --git-dir=${GITDIR}/.git show --format='%ai' | head -1`" -d ${CVSTMPDIR} ${CVS_MODULE}

sync-cvs-sametime-git2:
	${RM} -r -- cvstmp2
	${CVS} -d ${CVS_REPOSITORY_DIR} co -D"`${GIT} --git-dir=${GITDIR}/.git show --format='%ai' | head -1`" -d cvstmp2 ${CVS_MODULE}

compare-dir:
	./compare_dir ${CVSTMPDIR} ${GITDIR}

compare-dir-hack:
	./compare_dir -X ${CVSTMPDIR} ${GITDIR}


git-checkout-master:
	cd ${GITDIR} && ${GIT} checkout master && ${GIT} clean -f

push:
	./PUSH

# detect cvs repository has renamed/modified manually
copy-from-cvs-to-git-and-commit:
	cd ${GITDIR} && ${GIT} checkout master && ${GIT} clean -f
	cd ${CVSTMPDIR} && rsync --stats -vOcrI --exclude=CVS --exclude=.git --delete * ../${GITDIR}/
	${GIT} --git-dir=gitwork/.git show --format='%ai' | head -1 > ${WORKDIR2}/lastcommit
	-cd ${GITDIR} && ${GIT} add -A && env GIT_AUTHOR_DATE="`cat ../${WORKDIR2}/lastcommit`" GIT_COMMITTER_DATE="`cat ../${WORKDIR2}/lastcommit`" GIT_AUTHOR_NAME='from cvs to git' GIT_AUTHOR_EMAIL='from cvs to git' GIT_COMMITTER_NAME='from cvs to git' GIT_COMMITTER_EMAIL='from cvs to git' ${GIT} commit -m 'sync from cvs repository'

pullup_from_cvs_to_git:
	false

get-cvsrepository:
	${MKDIR} -- ${CVS_REPOSITORY_DIR}
	env RSYNC_PROXY=${RSYNC_PROXY} ./rsync_completely.sh rsync://anoncvs.NetBSD.org/cvsroot/CVSROOT ${CVS_REPOSITORY_DIR}
	env RSYNC_PROXY=${RSYNC_PROXY} ./rsync_completely.sh rsync://anoncvs.NetBSD.org/cvsroot/src     ${CVS_REPOSITORY_DIR}

cvscheckout:
	${CVS} -q -d ${CVS_REPOSITORY_DIR} co -d${CVSTMPDIR} ${CVS_MODULE}

cvsupdate:
	${RM} -r -- ${CVSTMPDIR}
	${CVS} -d ${CVS_REPOSITORY_DIR} co -d ${CVSTMPDIR} ${CVS_MODULE}

creategitimport:
	./jslog2fastexport ${CVS_REPOSITORY_DIR}/${CVS_MODULE} ${CVSTMPDIR} ${WORKDIR1}/commit.#trunk.jslog > ${WORKDIR1}/gitimportfile

gitreset:
	(cd ${GITDIR} && ${GIT} reset --hard)

gitimport:
	(cd ${GITDIR} && ${GIT} fast-import) < ${WORKDIR1}/gitimportfile

gitinit:
	${MKDIR} -- ${GITDIR}
	(cd ${GITDIR} && ${GIT} init)

jslog: makeworkdir1
	(here=`pwd`; cd ${CVS_REPOSITORY_DIR}/${CVS_MODULE} && find . -type f -name '*,v' -print0 | xargs -0 -n5000 $$here/rcs2js) > ${WORKDIR1}/log
	sort ${WORKDIR1}/log > ${WORKDIR1}/log.sorted
	${RM} -- ${WORKDIR1}/log
	./js2jslog_branch -d ${WORKDIR1} ${WORKDIR1}/log.sorted

branchinfo:
	(here=`pwd`; cd ${CVS_REPOSITORY_DIR}/${CVS_MODULE} && find . -type f -name '*,v' -print0 | xargs -0 -n5000 $$here/rcs2taginfo) > ${WORKDIR1}/branchinfo
	./branchinfo2branch ${WORKDIR1}/branchinfo > ${WORKDIR1}/branches
	./branchinfo2tag    ${WORKDIR1}/branchinfo > ${WORKDIR1}/tags

makeworkdir1:
	${MKDIR} -- ${WORKDIR1}

makeworkdir2:
	${MKDIR} -- ${WORKDIR2}
