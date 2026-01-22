{{/*
Wazuh-specific templates for init containers and agent configuration
*/}}

{{/*
Secret name for authd.pass
*/}}
{{- define "wazuh-agent.secretName" -}}
{{- if .Values.registration.existingSecret }}
{{- .Values.registration.existingSecret }}
{{- else }}
{{- include "wazuh-agent.fullname" . }}-authd
{{- end }}
{{- end }}

{{/*
Registration server (defaults to manager address)
*/}}
{{- define "wazuh-agent.registrationServer" -}}
{{- if .Values.registration.server }}
{{- .Values.registration.server }}
{{- else }}
{{- .Values.manager.address }}
{{- end }}
{{- end }}

{{/*
Helper to generate a volume definition based on type
Usage: include "wazuh-agent.volume" (dict "name" "wazuh-etc" "config" .Values.persistence.etc "fullname" (include "wazuh-agent.fullname" .))
*/}}
{{- define "wazuh-agent.volume" -}}
- name: {{ .name }}
{{- if eq .config.type "hostPath" }}
  hostPath:
    path: {{ .config.hostPath.path }}
    type: {{ .config.hostPath.type | default "DirectoryOrCreate" }}
{{- else if eq .config.type "emptyDir" }}
  emptyDir:
    {{- with .config.emptyDir }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
{{- else if eq .config.type "pvc" }}
  persistentVolumeClaim:
    claimName: {{ .fullname }}-{{ trimPrefix "wazuh-" .name }}
{{- end }}
{{- end }}

{{/*
Generate volumes from persistence configuration
*/}}
{{- define "wazuh-agent.volumes" -}}
{{- $fullname := include "wazuh-agent.fullname" . -}}
{{- if .Values.persistence.etc.enabled }}
{{ include "wazuh-agent.volume" (dict "name" "wazuh-etc" "config" .Values.persistence.etc "fullname" $fullname) }}
{{- end }}
{{- if .Values.persistence.logs.enabled }}
{{ include "wazuh-agent.volume" (dict "name" "wazuh-logs" "config" .Values.persistence.logs "fullname" $fullname) }}
{{- end }}
{{- if .Values.persistence.queue.enabled }}
{{ include "wazuh-agent.volume" (dict "name" "wazuh-queue" "config" .Values.persistence.queue "fullname" $fullname) }}
{{- end }}
{{- if .Values.persistence.var.enabled }}
{{ include "wazuh-agent.volume" (dict "name" "wazuh-var" "config" .Values.persistence.var "fullname" $fullname) }}
{{- end }}
{{- if .Values.persistence.activeResponse.enabled }}
{{ include "wazuh-agent.volume" (dict "name" "wazuh-active-response" "config" .Values.persistence.activeResponse "fullname" $fullname) }}
{{- end }}
{{- end }}

{{/*
Generate volumeMounts for main container
*/}}
{{- define "wazuh-agent.volumeMounts" -}}
{{- if .Values.persistence.etc.enabled }}
- name: wazuh-etc
  mountPath: /var/ossec/etc
{{- end }}
{{- if .Values.persistence.logs.enabled }}
- name: wazuh-logs
  mountPath: /var/ossec/logs
{{- end }}
{{- if .Values.persistence.queue.enabled }}
- name: wazuh-queue
  mountPath: /var/ossec/queue
{{- end }}
{{- if .Values.persistence.var.enabled }}
- name: wazuh-var
  mountPath: /var/ossec/var
{{- end }}
{{- if .Values.persistence.activeResponse.enabled }}
- name: wazuh-active-response
  mountPath: /var/ossec/active-response
{{- end }}
{{- end }}

{{/*
Generate volumeMounts for init containers (same paths, used for seeding)
*/}}
{{- define "wazuh-agent.initVolumeMounts" -}}
{{- if .Values.persistence.etc.enabled }}
- name: wazuh-etc
  mountPath: /mnt/etc
{{- end }}
{{- if .Values.persistence.logs.enabled }}
- name: wazuh-logs
  mountPath: /mnt/logs
{{- end }}
{{- if .Values.persistence.queue.enabled }}
- name: wazuh-queue
  mountPath: /mnt/queue
{{- end }}
{{- if .Values.persistence.var.enabled }}
- name: wazuh-var
  mountPath: /mnt/var
{{- end }}
{{- if .Values.persistence.activeResponse.enabled }}
- name: wazuh-active-response
  mountPath: /mnt/active-response
{{- end }}
{{- end }}


{{/*
Init container: cleanup stale files
*/}}
{{- define "wazuh-agent.initContainer.cleanupStaleFiles" -}}
- name: cleanup-stale-files
  image: {{ .Values.initImage.repository }}:{{ .Values.initImage.tag }}
  imagePullPolicy: {{ .Values.initImage.pullPolicy }}
  securityContext:
    runAsUser: 0
  command: ["/bin/sh", "-c"]
  args:
    - |
      set -euo pipefail
      # Clean up stale pid and lock files from previous runs
      rm -f /mnt/var/run/*.pid 2>/dev/null || true
      rm -f /mnt/queue/ossec/*.lock 2>/dev/null || true
  volumeMounts:
    {{- include "wazuh-agent.initVolumeMounts" . | nindent 4 }}
{{- end }}

{{/*
Init container: seed persistent volumes with initial data from image
*/}}
{{- define "wazuh-agent.initContainer.seedOssecTree" -}}
- name: seed-ossec-tree
  image: {{ .Values.image.repository }}:{{ .Values.image.tag }}
  imagePullPolicy: {{ .Values.image.pullPolicy }}
  securityContext:
    runAsUser: 0
  command: ["/bin/sh", "-c"]
  args:
    - |
      set -euo pipefail

      # Seed etc volume (only if empty - no ossec.conf yet)
      if [ -d /mnt/etc ] && [ ! -f /mnt/etc/ossec.conf ]; then
        echo "[init] Seeding etc volume..."
        cp -a /var/ossec/etc/* /mnt/etc/ 2>/dev/null || true
      fi

      # Seed logs volume (only if empty)
      if [ -d /mnt/logs ] && [ -z "$(ls -A /mnt/logs 2>/dev/null)" ]; then
        echo "[init] Seeding logs volume..."
        cp -a /var/ossec/logs/* /mnt/logs/ 2>/dev/null || true
      fi

      # Seed queue volume (only if empty)
      if [ -d /mnt/queue ] && [ -z "$(ls -A /mnt/queue 2>/dev/null)" ]; then
        echo "[init] Seeding queue volume..."
        cp -a /var/ossec/queue/* /mnt/queue/ 2>/dev/null || true
      fi

      # Seed var volume (only if empty)
      if [ -d /mnt/var ] && [ -z "$(ls -A /mnt/var 2>/dev/null)" ]; then
        echo "[init] Seeding var volume..."
        cp -a /var/ossec/var/* /mnt/var/ 2>/dev/null || true
      fi

      # Seed active-response volume (only if empty)
      if [ -d /mnt/active-response ] && [ -z "$(ls -A /mnt/active-response 2>/dev/null)" ]; then
        echo "[init] Seeding active-response volume..."
        cp -a /var/ossec/active-response/* /mnt/active-response/ 2>/dev/null || true
      fi

      echo "[init] Seeding complete."
  volumeMounts:
    {{- include "wazuh-agent.initVolumeMounts" . | nindent 4 }}
{{- end }}

{{/*
Init container: fix permissions on volumes
*/}}
{{- define "wazuh-agent.initContainer.fixPermissions" -}}
- name: fix-permissions
  image: {{ .Values.initImage.repository }}:{{ .Values.initImage.tag }}
  imagePullPolicy: {{ .Values.initImage.pullPolicy }}
  securityContext:
    runAsUser: 0
  command: ["/bin/sh", "-c"]
  args:
    - |
      set -euo pipefail
      # Fix ownership on all mounted volumes (wazuh user uid=999)
      [ -d /mnt/etc ] && chown -R 999:999 /mnt/etc || true
      [ -d /mnt/logs ] && chown -R 999:999 /mnt/logs || true
      [ -d /mnt/queue ] && chown -R 999:999 /mnt/queue || true
      [ -d /mnt/var ] && chown -R 999:999 /mnt/var || true
      [ -d /mnt/active-response ] && chown -R 999:999 /mnt/active-response || true
  volumeMounts:
    {{- include "wazuh-agent.initVolumeMounts" . | nindent 4 }}
{{- end }}

{{/*
Init container: write ossec config
*/}}
{{- define "wazuh-agent.initContainer.writeOssecConfig" -}}
- name: write-ossec-config
  image: {{ .Values.initImage.repository }}:{{ .Values.initImage.tag }}
  imagePullPolicy: {{ .Values.initImage.pullPolicy }}
  securityContext:
    runAsUser: 0
  env:
    - name: WAZUH_MANAGER
      value: {{ .Values.manager.address | quote }}
    - name: WAZUH_PORT
      value: {{ .Values.manager.port | quote }}
    - name: WAZUH_PROTOCOL
      value: {{ .Values.manager.protocol | quote }}
    - name: WAZUH_REGISTRATION_SERVER
      value: {{ include "wazuh-agent.registrationServer" . | quote }}
    - name: WAZUH_REGISTRATION_PORT
      value: {{ .Values.registration.port | quote }}
    - name: WAZUH_AGENT_NAME
      valueFrom:
        fieldRef:
          fieldPath: spec.nodeName
    - name: AGENT_NAME_PREFIX
      value: {{ .Values.agentNamePrefix | quote }}
  command: ["/bin/sh", "-c"]
  args:
    - |
      set -euo pipefail
      umask 007
      cp /config/ossec.conf /mnt/etc/ossec.conf
      if [ -n "${AGENT_NAME_PREFIX}" ]; then
        FINAL_AGENT_NAME="${AGENT_NAME_PREFIX}-${WAZUH_AGENT_NAME}"
      else
        FINAL_AGENT_NAME="${WAZUH_AGENT_NAME}"
      fi
      sed -i \
        -e "s|\${WAZUH_MANAGER}|${WAZUH_MANAGER}|g" \
        -e "s|\${WAZUH_PORT}|${WAZUH_PORT}|g" \
        -e "s|\${WAZUH_PROTOCOL}|${WAZUH_PROTOCOL}|g" \
        -e "s|\${WAZUH_REGISTRATION_SERVER}|${WAZUH_REGISTRATION_SERVER}|g" \
        -e "s|\${WAZUH_REGISTRATION_PORT}|${WAZUH_REGISTRATION_PORT}|g" \
        -e "s|\${WAZUH_AGENT_NAME}|${FINAL_AGENT_NAME}|g" \
        /mnt/etc/ossec.conf
      chown 999:999 /mnt/etc/ossec.conf
      chmod 0640 /mnt/etc/ossec.conf
  volumeMounts:
    {{- include "wazuh-agent.initVolumeMounts" . | nindent 4 }}
    - name: wazuh-config
      mountPath: /config
{{- end }}

{{/*
Init container: copy local options
*/}}
{{- define "wazuh-agent.initContainer.copyLocalOptions" -}}
- name: copy-local-options
  image: {{ .Values.initImage.repository }}:{{ .Values.initImage.tag }}
  imagePullPolicy: {{ .Values.initImage.pullPolicy }}
  securityContext:
    runAsUser: 0
  command: ["/bin/sh", "-c"]
  args:
    - |
      set -e
      cp /config/local_internal_options.conf /mnt/etc/local_internal_options.conf
      chown 999:999 /mnt/etc/local_internal_options.conf
      chmod 0640 /mnt/etc/local_internal_options.conf
  volumeMounts:
    {{- include "wazuh-agent.initVolumeMounts" . | nindent 4 }}
    - name: wazuh-config
      mountPath: /config
{{- end }}

{{/*
Init container: copy authd pass
*/}}
{{- define "wazuh-agent.initContainer.copyAuthdPass" -}}
- name: copy-authd-pass
  image: {{ .Values.initImage.repository }}:{{ .Values.initImage.tag }}
  imagePullPolicy: {{ .Values.initImage.pullPolicy }}
  securityContext:
    runAsUser: 0
  command: ["/bin/sh", "-c"]
  args:
    - |
      set -e
      cp /secret/authd.pass /mnt/etc/authd.pass
      chown 999:999 /mnt/etc/authd.pass
      chmod 0640 /mnt/etc/authd.pass
  volumeMounts:
    {{- include "wazuh-agent.initVolumeMounts" . | nindent 4 }}
    - name: wazuh-secret
      mountPath: /secret
{{- end }}

{{/*
Init container: copy custom active response scripts
*/}}
{{- define "wazuh-agent.initContainer.copyActiveResponseScripts" -}}
{{- if .Values.activeResponseScripts }}
- name: copy-active-response-scripts
  image: {{ .Values.initImage.repository }}:{{ .Values.initImage.tag }}
  imagePullPolicy: {{ .Values.initImage.pullPolicy }}
  securityContext:
    runAsUser: 0
  command: ["/bin/sh", "-c"]
  args:
    - |
      set -e
      echo "[init] Copying custom active response scripts..."
      mkdir -p /mnt/active-response/bin
      for script in /scripts/*; do
        if [ -f "$script" ]; then
          name=$(basename "$script")
          cp "$script" "/mnt/active-response/bin/$name"
          chown 999:999 "/mnt/active-response/bin/$name"
          chmod 0750 "/mnt/active-response/bin/$name"
          echo "[init] Installed script: $name"
        fi
      done
  volumeMounts:
    {{- include "wazuh-agent.initVolumeMounts" . | nindent 4 }}
    - name: wazuh-scripts
      mountPath: /scripts
{{- end }}
{{- end }}
