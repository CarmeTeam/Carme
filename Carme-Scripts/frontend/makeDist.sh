#NOTE MOVE TO BACKEND
#!/bin/bash
rm -r dist*
ls *.py | cut -d'.' -f 1| xargs -i cxfreeze '{}'.py --target-dir dist_'{}'
