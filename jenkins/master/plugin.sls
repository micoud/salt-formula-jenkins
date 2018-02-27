{% from "jenkins/map.jinja" import master with context %}

# RedHat-specific
# TODO make this generic
# make sure group nogroup is present
nogroup_present:
  group.present:
    - name: nogroup

{{ master.home }}/updates:
  file.directory:
  - user: jenkins
  - group: nogroup
  - require:
    - nogroup_present

setup_jenkins_cli:
  cmd.run:
  - names:
    - wget http://localhost:{{ master.http.port }}/jnlpJars/jenkins-cli.jar
  - unless: "[ -f /root/jenkins-cli.jar ]"
  - cwd: /root
  - require:
    - cmd: jenkins_service_running

{%- for plugin in master.plugins %}

install_jenkins_plugin_{{ plugin.name }}:
  cmd.run:
  - name: >
      java -jar jenkins-cli.jar -s http://localhost:{{ master.http.port }} install-plugin {{ plugin.name }} ||
      java -jar jenkins-cli.jar -s http://localhost:{{ master.http.port }} install-plugin --username admin --password {{ master.user.admin.password }} {{ plugin.name }}
  - unless: "[ -d {{ master.home }}/plugins/{{ plugin.name }} ]"
  - cwd: /root
  - require:
    - cmd: setup_jenkins_cli
    - cmd: jenkins_service_running

{%- endfor %}
