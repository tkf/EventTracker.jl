# Gallery

## Fibonacci

### Serial fibonacci

```@example fibonacci-serial
using EventTracker

function fib(n)
    n <= 1 && return n
    @recordinterval :fib1 a = fib(n - 1)
    @recordinterval :fib2 b = fib(n - 2)
    return a + b
end

EventTracker.clear()
fib(10)

df = EventTracker.summary_dataframe()
```

```@example fibonacci-serial
using Plots
stks = EventTracker.stacks()
plot(stks)
savefig("fibonacci-serial-stacks.svg"); nothing # hide
```

![](fibonacci-serial-stacks.svg)

### Parallel fibonacci

```@example fibonacci-spin
using EventTracker

function fib(n)
    n <= 1 && return n
    t = @async begin
        rand(Bool) && yield()  # introduce more task jugglings
        @recordinterval :fib1 fib(n - 1)
    end
    @recordinterval :fib2 b = fib(n - 2)
    return (fetch(t)::Int) + b
end
nothing # hide
```

```@example fibonacci-spin
function withspin(f)
    done = Threads.Atomic{Bool}(false)
    @sync begin
        Threads.@spawn begin
            while !done[]
                @recordpoint :spin
                yield()
            end
        end
        try
            f()
        finally
            done[] = true
        end
    end
end

function run_fibs_with_spin(nums)
    withspin() do
        for n in nums
            fib(n)
        end
    end
end
run_fibs_with_spin([5, 6, 7])  # invoke compilation
nothing # hide
```

```@example fibonacci-spin
EventTracker.clear()
run_fibs_with_spin([5, 6, 7])

df = EventTracker.summary_dataframe()
```

```@example fibonacci-spin
using Plots
stks = EventTracker.stacks()
plot(stks)
savefig("fibonacci-spin-stacks.svg"); nothing # hide
```

![](fibonacci-spin-stacks.svg)

## Tarai

Ref: [Tak (function) - Wikipedia](https://en.wikipedia.org/wiki/Tak_(function))

```@example tarai-serial
using EventTracker

function tarai(x, y, z)
    @recordinterval if y < x
        tarai(
            tarai(x - 1, y, z),
            tarai(y - 1, z, x),
            tarai(z - 1, x, y),
        )
    else
        @recordpoint
        y
    end
end

EventTracker.clear()
tarai(3, 1, 7)
df = EventTracker.summary_dataframe()
```

```@example tarai-serial
using Plots
stks = EventTracker.stacks()
plot(stks)
savefig("tarai-serial-stacks.png"); nothing # hide
```

![](tarai-serial-stacks.png)
