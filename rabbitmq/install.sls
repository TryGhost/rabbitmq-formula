{% from "rabbitmq/package-map.jinja" import pkgs with context %}

{% set module_list = salt['sys.list_modules']() %}
{% if 'rabbitmqadmin' in module_list %}
include:
  - .config_bindings
  - .config_queue
  - .config_exchange
{% endif %}

{% if salt['pillar.get']('rabbitmq:manage_repo', False) %}
rabbitmq-repo-deps:
  pkg.installed:
    - pkgs:
      - curl
      - gnupg
      - apt-transport-https

rabbitmq-repo:
  pkgrepo.managed:
    - humanname: rabbitmq
    - name: deb https://packagecloud.io/rabbitmq/rabbitmq-server/ubuntu/ {{ salt['grains.get']('oscodename', 'trusty')|lower }} main
    - key_url: https://packagecloud.io/rabbitmq/rabbitmq-server/gpgkey
    - refresh_db: True
{% endif %}

{% if salt['pillar.get']('rabbitmq:manage_erlang', False) %}
erlang-repo:
  pkgrepo.managed:
    - humanname: erlang-solutions
    - name: deb https://packages.erlang-solutions.com/ubuntu {{ salt['grains.get']('oscodename', 'trusty')|lower }} contrib
    - key_url: https://packages.erlang-solutions.com/ubuntu/erlang_solutions.asc
    - refresh_db: True

erlang-package:
  pkg.installed:
    - name: erlang
    {%- if 'erlang_version' in salt['pillar.get']('rabbitmq', {}) %}
    - version: {{ salt['pillar.get']('rabbitmq:erlang_version') }}
    {%- endif %}
{% endif %}

rabbitmq-server:
  pkg.installed:
    - name: {{ pkgs['rabbitmq-server'] }}
    {%- if 'version' in salt['pillar.get']('rabbitmq', {}) %}
    - version: {{ salt['pillar.get']('rabbitmq:version') }}
    {%- endif %}

{% if salt['pillar.get']('rabbitmq:erlang_cookie', False) %}
  file.managed:
    - makedirs: True
    - name: /var/lib/rabbitmq/.erlang.cookie
    - mode: 400
    - user: rabbitmq
    - group: rabbitmq
    - contents_pillar: rabbitmq:erlang_cookie
    - require:
      - pkg: rabbitmq-server
    - require_in:
      - service: rabbitmq-server
  cmd.run:
    - name: killall -u rabbitmq
    - onchanges:
      - file: /var/lib/rabbitmq/.erlang.cookie
    - require_in:
      - service: rabbitmq-server
{% endif %}

  service:
    - {{ "running" if salt['pillar.get']('rabbitmq:running', True) else "dead" }}
    - enable: {{ salt['pillar.get']('rabbitmq:enabled', True) }}
    - watch:
      - pkg: rabbitmq-server

rabbitmq_binary_tool_env:
  file.symlink:
    - makedirs: True
    - name: /usr/local/bin/rabbitmq-env
    - target: /usr/lib/rabbitmq/bin/rabbitmq-env
    - require:
      - pkg: rabbitmq-server

rabbitmq_binary_tool_plugins:
  file.symlink:
    - makedirs: True
    - name: /usr/local/bin/rabbitmq-plugins
    - target: /usr/lib/rabbitmq/bin/rabbitmq-plugins
    - require:
      - pkg: rabbitmq-server
      - file: rabbitmq_binary_tool_env
