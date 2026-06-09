#!/bin/sh
# Portable functional suite for redis: starts $REDIS_SERVER on a unix socket,
# drives it with redis-cli, prints every command and reply, and asserts a few
# core behaviors. Needs only POSIX sh.
#
# Two consumers:
#  - legacy_test_functional / bazel_test_functional: the assertions must pass.
#  - parity_test (suite mode): the *entire output* must be byte-identical
#    between the legacy and Bazel builds, so everything printed here must be
#    deterministic: no KEYS/SMEMBERS on hashtable encodings (iteration order
#    depends on the per-run siphash seed), no randomized commands
#    (SRANDMEMBER, SPOP, RANDOMKEY, LOLWUT), no timestamps/PIDs/paths.
#
# REDIS_SERVER must point at redis-server; REDIS_CLI defaults to the
# redis-cli sitting next to it.
set -u

: "${REDIS_SERVER:?REDIS_SERVER must point at the redis-server binary under test}"
REDIS_CLI=${REDIS_CLI:-"$(dirname "$REDIS_SERVER")/redis-cli"}

workdir=$(mktemp -d)
sock="$workdir/redis.sock"

"$REDIS_SERVER" --unixsocket "$sock" --port 0 --daemonize no \
    --save '' --appendonly no --dir "$workdir" \
    --logfile "$workdir/server.log" &
server_pid=$!

tries=0
until "$REDIS_CLI" -s "$sock" ping > /dev/null 2>&1; do
    tries=$((tries + 1))
    if [ "$tries" -gt 100 ]; then
        echo "FATAL: server did not become ready" >&2
        cat "$workdir/server.log" >&2
        exit 1
    fi
    sleep 0.1
done

fails=0

# Print the command and its raw reply.
r() {
    echo "> $*"
    "$REDIS_CLI" -s "$sock" "$@"
}

# Assert the reply to a command equals an expected string.
expect() {
    expected=$1
    shift
    actual=$("$REDIS_CLI" -s "$sock" "$@")
    echo "> $*"
    echo "$actual"
    if [ "$actual" != "$expected" ]; then
        echo "ASSERTION FAILED: '$*' => '$actual', expected '$expected'" >&2
        fails=$((fails + 1))
    fi
}

echo "=== core ==="
expect "PONG" ping
expect "OK" set greeting "hello from the parity suite"
expect "hello from the parity suite" get greeting
r command count
r dbsize

echo "=== strings ==="
r set counter 41
r incr counter
r incrby counter 100
r incrbyfloat counter 0.5
r append greeting "!"
r strlen greeting
r getrange greeting 0 4
r setrange greeting 0 HELLO
r get greeting
r object encoding counter
r object encoding greeting

echo "=== bits ==="
r setbit bits 7 1
r getbit bits 7
r bitcount bits
r setbit bits 100 1
r bitcount bits

echo "=== expiry ==="
r set ephemeral here ex 10000
r ttl ephemeral
r persist ephemeral
r ttl ephemeral
r exists ephemeral missing

echo "=== lists ==="
r rpush mylist a b c d e
r lrange mylist 0 -1
r lpush mylist z
r lindex mylist 0
r linsert mylist before c XX
r lrange mylist 0 -1
r lpop mylist
r rpop mylist 2
r llen mylist
r lpos mylist XX
r object encoding mylist

echo "=== hashes ==="
r hset myhash f1 v1 f2 v2 f3 3
r hget myhash f2
r hincrby myhash f3 7
r hgetall myhash
r hdel myhash f1
r hlen myhash
r object encoding myhash

echo "=== sets (deterministic encodings only) ==="
r sadd intset 3 1 2
r smembers intset
r object encoding intset
r sismember intset 2
r scard intset
r sadd otherints 2 3 4
r sintercard 2 intset otherints

echo "=== sorted sets ==="
r zadd board 1.5 alice 2.25 bob 0.5 carol
r zrange board 0 -1 withscores
r zscore board bob
r zincrby board 10 carol
r zrangebyscore board 1 3
r zrank board bob
r zcard board

echo "=== type errors and edge cases ==="
r incr greeting
r lpush greeting nope
r get mylist
r expire missing 100
r getdel counter
r get counter

echo "=== encodings under growth ==="
# shellcheck disable=SC2046
r rpush biglist $(seq 1 200) > /dev/null
echo "> rpush biglist 1..200 (output elided)"
r llen biglist
r object encoding biglist

echo "=== lua scripting (exercises bundled lua + cjson + struct + cmsgpack + bit) ==="
expect "2" eval "return 1+1" 0
r eval "return redis.call('set', KEYS[1], ARGV[1])" 1 luakey luaval
r get luakey
r eval "return cjson.encode({1,2,3,'four'})" 0
r eval "return tostring(cjson.decode('[10,20,30]')[2])" 0
r eval "return redis.sha1hex('')" 0
r eval "return tostring(bit.band(7,3))" 0
r eval "return tostring((struct.unpack('>I2','AB')))" 0
r eval "return cmsgpack.unpack(cmsgpack.pack('roundtrip'))" 0
r eval "return {KEYS[1],ARGV[1],ARGV[2]}" 1 k a1 a2
r eval "return redis.error_reply('custom error')" 0
r eval "this is not lua" 0

echo "=== functions ==="
r function load "#!lua name=paritylib
redis.register_function('parityfn', function(keys, args) return 42 end)"
expect "42" fcall parityfn 0
r function list

echo "=== server introspection (stable fields only) ==="
"$REDIS_CLI" -s "$sock" info | tr -d '\r' | grep -E '^(redis_version|redis_git_sha1|redis_git_dirty|redis_mode|arch_bits|multiplexing_api|mem_allocator|io_threads_active):'
r config get maxmemory
r config get appendonly
r acl whoami
r dbsize

echo "=== shutdown ==="
"$REDIS_CLI" -s "$sock" shutdown nosave 2> /dev/null
wait "$server_pid"
server_exit=$?
echo "server exit code: $server_exit"
[ "$server_exit" -eq 0 ] || fails=$((fails + 1))

echo "# functional suite: $fails failures"
[ "$fails" -eq 0 ]
