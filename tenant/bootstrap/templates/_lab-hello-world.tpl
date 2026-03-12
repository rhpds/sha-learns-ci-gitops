{{- define "labHelloWorld" -}}
{{- $defaults := (.Files.Get "values-lab-hello-world.yaml" | fromYaml).labHelloWorld | default dict -}}
{{- $overrides := .Values.labHelloWorld | default dict -}}
{{- mergeOverwrite $defaults $overrides | toYaml -}}
{{- end -}}
