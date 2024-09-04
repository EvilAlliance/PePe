if [[ -z $1 ]] && [[ $1 -eq "replay" ]]; then
    python3 ./test/rere.py replay ./test/test.list
elif [[ -z $1 ]] && [[ $1 -eq "record" ]]; then
    python3 ./test/rere.py record ./test/test.list
else
    python3 ./test/rere.py replay ./test/test.list
fi
