// Package converter is a stub that omits all config converters.
package converter

import (
	"github.com/grafana/alloy/internal/converter/diag"
)

type Input string

const (
	InputOtelCol    Input = "otelcol"
	InputPrometheus Input = "prometheus"
	InputPromtail   Input = "promtail"
	InputStatic     Input = "static"
)

var SupportedFormats = []string{
	string(InputOtelCol),
	string(InputPrometheus),
	string(InputPromtail),
	string(InputStatic),
}

func Convert(in []byte, kind Input, extraArgs []string) ([]byte, diag.Diagnostics) {
	var diags diag.Diagnostics
	diags.Add(diag.SeverityLevelCritical, "config converters are not included in this build")
	return nil, diags
}
