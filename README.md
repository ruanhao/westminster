westminster
===========

Purpose
-------
Erlang Cluster Interconnection Application

When to use
-----------
Set up a hidden Erlang node which connects to distributed environment.
Program which analyses Erlang cluster performance can be hosted on such hidden node. Example: [akita], [labrador]

Topology
--------
```
                                              __________
                                             |  node    |
                                            /|__________|\
                                           /              \
        __________            __________  /                \
       |  hidden  |<-------->| central  |                    __________
       |__node____|          |__node____|     distributed   |  node    |
                                       \        nodes       |__________|
                                        \                  /
                                         \                /
                                          \   __________ /
                                            \|  node    |
                                             |__________|
                                             
```

How to use
----------
[rebar] is used to build Erlang project here.
Add the code below to **rebar.config** under project directory.
```erlang
{deps, [{westminster, ".*", {git, "https://github.com/ruanhao/westminster.git", {branch, "master"}}}]}.
```
Then run `rebar get-deps`, [westminster] will be automatically pulled into **deps** directory
which is defined in rebar configuration.
Write **central_node** entry into *westminster/src/westminster.app.src* like below.
```erlang
{application, westminster,
    [{description, "Erlang cluster setup application"},
     {vsn, "0.1.0"},
     {registered, []},
     {applications, [kernel, stdlib]},
     {mod, {westminster_app, []}},
     {env, [{central_node, 'central_node@host'}]}]}.    %% specify central_node
```
Remember to tart your hidden node **with westminster load path appointed**. Like:
```bash
erl -sname your_node_name -pa $PWD/ebin $PWD/deps/*/ebin -hidden -setcookie cluster_cookie
```
Finally, run `application:start(westminster).` in Erlang shell.  
And you can check the state by `application:get_env(westminster, cluster_meshed).`.

Acknowledgement
---------------
[Shuai Li] is a devil who persuade me (a Vimmer) to try Emacs.  
By the way, I like Emacs now :p

Is westminster good
-------------------
What about a cup of beverage :)  
[![Donate]](http://goo.gl/6zcOL)

  [akita]:  https://github.com/ruanhao/akita.git
  [labrador]:  https://github.com/ruanhao/labrador.git
  [rebar]:  https://github.com/basho/rebar.git
  [westminster]:  https://github.com/ruanhao/westminster.git
  [Shuai Li]:  https://github.com/javaforfun
  [Donate]:  https://www.paypal.com/en_US/i/btn/btn_donate_SM.gif
