#!/bin/bash
sleep 0.3
python3 -c "
path = '/home/zerda/.config/starship/starship.toml'
c = open(path).read()
c = c.replace('PLEFT', '\ue0b6')
c = c.replace('PRIGHT', '\ue0b4')
c = c.replace('ARCH', '\uf303')
open(path, 'w').write(c)
"
