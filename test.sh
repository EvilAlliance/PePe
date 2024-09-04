if [[ -z $1 ]] && [[ $1 -eq "replay" ]]; then
    ./test/rere.py replay ./test/test.list
elif [[ -z $1 ]] && [[ $1 -eq "record" ]]; then
    ./test/rere.py record ./test/test.list
else
    ./test/rere.py replay ./test/test.list
fi
