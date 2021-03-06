{% for name, plugin in salt["pillar.get"]("rabbitmq:plugin", {}).items() %}
{{ name }}:
  rabbitmq_plugin:
    {% for value in plugin %}
    - {{ value }}
    {% endfor %}
    - runas: root
    - require:
      - pkg: rabbitmq-server
      - file: rabbitmq_binary_tool_plugins
    - watch_in:
      - service: rabbitmq-server
{% endfor %}

{% for name, vhost in salt["pillar.get"]("rabbitmq:vhost", {}).items() %}
rabbitmq_vhost_{{ name }}:
  rabbitmq_vhost.present:
    - name: {{ vhost }}
    - require:
      - service: rabbitmq-server
{% endfor %}
{% if salt['pillar.get']('rabbitmq:monitoring_vhost', False) %}
rabbitmq_monitoring_vhost:
  rabbitmq_vhost.present:
    - name: {{ salt['pillar.get']('rabbitmq:monitoring_vhost') }}
    - require:
      - service: rabbitmq-server
{% endif %}

{% for name, policy in salt["pillar.get"]("rabbitmq:policy", {}).items() %}
{{ name }}:
  rabbitmq_policy.present:
    {% for value in policy %}
    - {{ value }}
    {% endfor %}
    - require:
      - service: rabbitmq-server
{% endfor %}

{% for name, user in salt["pillar.get"]("rabbitmq:user", {}).items() %}
rabbitmq_user_{{ name }}:
  rabbitmq_user.present:
    - name: {{ name }}
    {% for value in user %}
    - {{ value }}
    {% endfor %}
    - require:
      - service: rabbitmq-server
{% endfor %}

{% if salt['pillar.get']('rabbitmq:remove_guest', False) %}
remove_guest_user:
  rabbitmq_user.absent:
    - name: guest
    - require:
      - service: rabbitmq-server
{% endif %}

{% if salt['pillar.get']('rabbitmq:admin_user', False) %}
rabbitmq_admin_user:
  rabbitmq_user.present:
    - name: {{ salt['pillar.get']('rabbitmq:admin_user') }}
    - password: {{ salt['pillar.get']('rabbitmq:admin_pass') }}
    - force: True
    - tags: administrator
    - perms:
      - '/':
        - '.*'
        - '.*'
        - '.*'
{% for name, vhost in salt["pillar.get"]("rabbitmq:vhost", {}).items() if not vhost == '/' %}
      - {{ vhost }}:
        - '.*'
        - '.*'
        - '.*'
{% endfor %}
    - runas: root
    - require:
      - service: rabbitmq-server
{% endif %}

{% if salt['pillar.get']('rabbitmq:monitoring_user', False) %}

rabbitmq_monitoring_user:
  rabbitmq_user.present:
    - name: {{ salt['pillar.get']('rabbitmq:monitoring_user') }}
    - password: {{ salt['pillar.get']('rabbitmq:monitoring_pass') }}
    - force: True
    - tags: monitoring
    - runas: root
    - perms:
      - '{{ salt['pillar.get']('rabbitmq:monitoring_vhost', '/') }}':
        - '.*'
        - '.*'
        - '.*'
    - require:
      - service: rabbitmq-server
{% endif %}

{% if salt['pillar.get']('rabbitmq:cluster', False) %}
{% for cluster_host_name in salt['pillar.get']('rabbitmq:cluster_hosts', []) %}
{% if cluster_host_name != grains['id'] %}
rabbit@{{ cluster_host_name }}:
  rabbitmq_cluster.joined:
    - user: rabbit
    - host: {{ cluster_host_name }}
    - require:
      - service: rabbitmq-server
{% endif %}
{% endfor %}
{% endif %}
