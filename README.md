westminster
===========

Erlang Cluster Interconnection Application

{deps, [{westminster, ".*", {git, "git@github.com:ruanhao/westminster.git", {branch, "master"}}}]}.


{application, westminster,
 [{description, "Erlang cluster setup application"},
  {vsn, "0.1.0"},
  {registered, []},
  {applications, [kernel, stdlib]},
  {mod, {westminster_app, []}},
  {env, [{central_node, 'central_node@host}]}]}.

