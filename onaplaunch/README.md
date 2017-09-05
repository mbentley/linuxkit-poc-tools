onaplaunch
==========

You only need a Docker Engine + running the `_all.sh` script to launch ONAP.

```
# ./_all.sh launch
```

Due to some hard coded values in the default [oom](https://github.com/mbentley/oom) configuration, you must override these DNS entries in your hosts file (replacing the IP with whatever the IP of your instance is):

```
52.87.252.195 policy.api.simpledemo.openecomp.org
52.87.252.195 portal.api.simpledemo.openecomp.org
52.87.252.195 sdc.api.simpledemo.openecomp.org
52.87.252.195 vid.api.simpledemo.openecomp.org
```

Default login credentials:

http://portal.api.simpledemo.openecomp.org:8989/ECOMPPORTAL/login.htm
```
 username - demo
 password - demo123456!
```
