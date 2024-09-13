if [[ -n $1 ]] && [[ "$1" = "replay" ]]; then
    ./test/rere.py replay ./test/test.list
elif [[ -n $1 ]] && [[ "$1" = "record" ]]; then
   ./test/rere.py record ./test/test.list
else 
    ./test/rere.py replay ./test/test.list
fi
