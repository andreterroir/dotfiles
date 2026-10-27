approved_yubikeys=(
{{ range .approvedYubiKeys }}	'{{ . }}'
{{ end }})
