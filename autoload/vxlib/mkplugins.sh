#!/bin/sh
vimdir="../.."
audir="../../autoload"
plugdir="../../plugin"
python ${audir}/vxlib/plugin.py ${audir} --indent 1 -o ${plugdir}/_vimuiex_autogen_.vim --update --config ${vimdir}/vxplugin.conf 
# python ${audir}/vxlib/plugin.py --no-require ${audir} > ${plugdir}/_vimuiex_autogen_.vim
