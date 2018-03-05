{%- from "jenkins/map.jinja" import master with context %}
{%- if master.enabled %}

include:
- java

# RedHat specific
{%- if grains.get('os_family', 'RedHat') %}
# make sure python-pip is installed
pip_installed:
  pkg.installed:
    - pkgs:
      - python2-pip
      - python-devel
      - gcc

# make sure python-bcrypt is installed via pip
python-bcrypt_installed:
  pip.installed:
    - name: bcrypt
    - require:
      - pip_installed
{%- endif %}

jenkins_repository:
  # todo include option for weekly build
  pkgrepo.managed:
    - humanname: Jenkins upstream package repository
    {% if grains['os_family'] == 'RedHat' %}
    - baseurl: {{ master.repo_url_stable }}
    - gpgkey: {{ master.repo_key_stable }}
    - name: jenkins
    {% elif grains['os_family'] == 'Debian' %}
    - file: {{ jenkins.deb_apt_source }}
    - name: deb {{ master.repo_url_stable }} binary/
    - key_url: {{ master.repo_key_stable }}
    {% endif %}
    - require_in:
      - jenkins_packages

jenkins_packages:
  pkg.installed:
  - names: {{ master.pkgs }}

jenkins_{{ master.config }}:
  file.managed:
  - name: {{ master.config }}
  {% if grains['os_family'] == 'RedHat' %}
  - source: salt://jenkins/files/RedHat/jenkins.conf
  {% elif grains['os_family'] == 'Debian' %}
  - source: salt://jenkins/files/Debian/jenkins.conf
  {% endif %}
  - user: root
  - group: root
  - template: jinja
  - require:
    - pkg: jenkins_packages

jenkins_init.groovy.d_directory_present:
  file.directory:
    - name: {{ master.home }}/init.groovy.d/
    - user: {{ master.jenkins_user }}
    - group: {{ master.jenkins_group }}
    - dir_mode: 755
    - file_mode: 644
    - recurse:
      - user
      - group
      - mode

{%- for script in master.groovy_config_scripts_present %}
ensure_{{ script.name }}_present:
  file.managed:
    - name: {{ master.home }}/init.groovy.d/{{ script.name }}
    - source: salt://jenkins/files/groovy/{{ script.name }}
    - user: {{ master.jenkins_user }}
    - group: {{ master.jenkins_group }}
    - required:
      - jenkins_init.groovy.d_directory_present
{%- endfor %}

{%- for script in master.groovy_config_scripts_absent %}
ensure_{{ script.name }}_absent:
  file.absent:
    - name: {{ master.home }}/init.groovy.d/{{ script.name }}
{%- endfor %}

{%- if master.get('no_config', False) == False %}
{{ master.home }}/config.xml:
  file.managed:
  - source: salt://jenkins/files/config.xml
  - template: jinja
  - user: {{ master.jenkins_user }}
  - group: {{ master.jenkins_group }}
  - watch_in:
    - service: jenkins_master_service
{%- endif %}

{%- if master.update_site_url is defined %}

{{ master.home }}/hudson.model.UpdateCenter.xml:
  file.managed:
  - source: salt://jenkins/files/hudson.model.UpdateCenter.xml
  - template: jinja
  - user: {{ master.jenkins_user }}
  - group: {{ master.jenkins_group }}
  - require:
    - pkg: jenkins_packages

{%- endif %}

{%- if master.approved_scripts is defined %}

{{ master.home }}/scriptApproval.xml:
  file.managed:
  - source: salt://jenkins/files/scriptApproval.xml
  - template: jinja
  - user: {{ master.jenkins_user }}
  - group: {{ master.jenkins_group }}
  - require:
    - pkg: jenkins_packages

{%- endif %}

{%- if master.email is defined %}

{{ master.home }}/hudson.tasks.Mailer.xml:
  file.managed:
  - source: salt://jenkins/files/hudson.tasks.Mailer.xml
  - template: jinja
  - user: {{ master.jenkins_user }}
  - group: {{ master.jenkins_group }}
  - require:
    - pkg: jenkins_packages

{%- endif %}

{%- if master.get('sudo', false) %}

/etc/sudoers.d/99-jenkins-user:
  file.managed:
  - source: salt://jenkins/files/sudoer
  - template: jinja
  - user: root
  - group: root
  - mode: 440
  - require:
    - service: jenkins_master_service

{%- endif %}

jenkins_master_service:
  service.running:
  - name: {{ master.service }}
  - watch:
    - file: jenkins_{{ master.config }}
    - file: {{ master.home }}/hudson.model.UpdateCenter.xml

jenkins_service_running:
  cmd.wait:
    - name: "i=0; while true; do curl -s -f http://localhost:{{ master.http.port }}/login >/dev/null && exit 0; [ $i -gt 60 ] && exit 1; sleep 5; done"
    - watch:
      - service: jenkins_master_service

{%- endif %}
