#!/bin/sh
audir="../../autoload"
plugdir="../../plugin"
python ${audir}/vxlib/plugin.py ${audir} > ${plugdir}/_vimuiex_autogen_.vim
# python ${audir}/vxlib/plugin.py --no-require ${audir} > ${plugdir}/_vimuiex_autogen_.vim
