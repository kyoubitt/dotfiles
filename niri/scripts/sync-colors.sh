#!/bin/bash
COLOR=$(python3 -c "
import json
c=json.load(open('$HOME/.cache/wallust/colors.json'))
# brighten color4 a bit
r,g,b=int(c['colors']['color4'][1:3],16),int(c['colors']['color4'][3:5],16),int(c['colors']['color4'][5:7],16)
r=min(255,int(r*1.3));g=min(255,int(g*1.3));b=min(255,int(b*1.3))
print(f'#{r:02X}{g:02X}{b:02X}')
")
python3 -c "
f=open('$HOME/.config/niri/config.kdl');c=f.read();f.close()
import re
c=re.sub(r'active-color \"#[0-9a-fA-F]+\"',f'active-color \"${COLOR}bb\"',c)
open('$HOME/.config/niri/config.kdl','w').write(c)
"
niri msg action reload-config 2>/dev/null || true
