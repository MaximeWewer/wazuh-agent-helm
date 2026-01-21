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
      mkdir -p /agent/var/run /agent/queue/ossec
      rm -f /agent/var/run/*.pid /agent/queue/ossec/*.lock || true
  volumeMounts:
    - name: wazuh-agent-data
      mountPath: /agent
{{- end }}

{{/*
Init container: seed ossec tree
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
      mkdir -p /agent
      if [ ! -d /agent/bin ] && [ ! -f /agent/etc/ossec.conf ]; then
        echo "[init] Seeding /var/ossec into PVC..."
        tar -C /var/ossec -cf - . | tar -C /agent -xpf -
      else
        echo "[init] PVC already has ossec runtime; skipping seed."
      fi
  volumeMounts:
    - name: wazuh-agent-data
      mountPath: /agent
{{- end }}

{{/*
Init container: fix permissions
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
      for d in etc logs queue var rids tmp "active-response"; do
        [ -d "/agent/$d" ] && chown -R 999:999 "/agent/$d"
      done
      [ -d /agent/bin ] && chown -R 0:0 /agent/bin || true
      [ -d /agent/lib ] && chown -R 0:0 /agent/lib || true
      [ -d /agent/bin ] && find /agent/bin -type f -exec chmod 0755 {} \; || true
      chmod 0755 /agent || true
  volumeMounts:
    - name: wazuh-agent-data
      mountPath: /agent
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
      mkdir -p /agent/etc /agent/var/run /agent/var /agent/logs /agent/queue
      cp /config/ossec.conf /agent/etc/ossec.conf
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
        /agent/etc/ossec.conf
      chown 999:999 /agent/etc/ossec.conf
      chmod 0640 /agent/etc/ossec.conf
  volumeMounts:
    - name: wazuh-agent-data
      mountPath: /agent
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
      mkdir -p /agent/etc
      cp /config/local_internal_options.conf /agent/etc/local_internal_options.conf
      chown 999:999 /agent/etc/local_internal_options.conf
      chmod 0640 /agent/etc/local_internal_options.conf
  volumeMounts:
    - name: wazuh-agent-data
      mountPath: /agent
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
      mkdir -p /agent/etc
      cp /secret/authd.pass /agent/etc/authd.pass
      chown 999:999 /agent/etc/authd.pass
      chmod 0640 /agent/etc/authd.pass
  volumeMounts:
    - name: wazuh-agent-data
      mountPath: /agent
    - name: wazuh-secret
      mountPath: /secret
{{- end }}
