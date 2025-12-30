# Local Static Checks
## git status -sb
## qa/final-qc-20251230
?? qa_evidence/

## git submodule status

## ls -la .github/workflows
total 44
drwxr-xr-x 2 root root 4096 Dec 30 15:29 .
drwxr-xr-x 5 root root 4096 Dec 30 15:29 ..
-rw-r--r-- 1 root root 1140 Dec 30 07:19 build-cu128.yml
-rw-r--r-- 1 root root 7229 Dec 30 15:29 build-cu130-nightly.yml
-rw-r--r-- 1 root root 5760 Dec 30 15:29 build-cu130.yml
-rw-r--r-- 1 root root 1100 Dec 30 07:19 build.yml
-rw-r--r-- 1 root root 1744 Dec 30 07:19 copilot-setup-steps.yml
-rw-r--r-- 1 root root 3333 Dec 30 07:19 scorecard.yml
-rw-r--r-- 1 root root  600 Dec 30 07:19 test-build.yml
## Workflow YAML validity
+ actionlint not available; attempting python YAML parse
NOT RUN: PyYAML not available (No module named 'yaml')

## Shell sanity (bash -n)
PASS: ./docs/debug-list.sh
PASS: ./builder/generate-pak7.sh
PASS: ./builder/attachments/备用脚本/force-update-cn.sh
PASS: ./builder/attachments/ExtraScripts/force-update-all.sh
PASS: ./builder/stage2.sh
PASS: ./builder/stage1.sh
PASS: ./builder/stage3.sh
PASS: ./builder/generate-pak5.sh
PASS: ./builder-cu130/generate-pak7.sh
PASS: ./builder-cu130/attachments/备用脚本/force-update-cn.sh
PASS: ./builder-cu130/attachments/ExtraScripts/force-update-all.sh
PASS: ./builder-cu130/stage2.sh
PASS: ./builder-cu130/stage1.sh
PASS: ./builder-cu130/stage3.sh
PASS: ./builder-cu130/generate-pak5.sh
PASS: ./builder-cu128/generate-pak7.sh
PASS: ./builder-cu128/attachments/备用脚本/force-update-cn.sh
PASS: ./builder-cu128/attachments/ExtraScripts/force-update-all.sh
PASS: ./builder-cu128/stage2.sh
PASS: ./builder-cu128/stage1.sh
PASS: ./builder-cu128/stage3.sh
PASS: ./builder-cu128/generate-pak5.sh

## shellcheck (optional)
NOT RUN: shellcheck not available

## Python compileall
