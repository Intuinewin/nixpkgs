{ buildGoModule
, fetchFromGitHub
, lib
, stdenv
}:

buildGoModule rec {
  pname = "opentelemetry-collector-contrib";
  version = "0.77.0";

  src = fetchFromGitHub {
    owner = "open-telemetry";
    repo = "opentelemetry-collector-contrib";
    rev = "v${version}";
    hash = "sha256-9OFNJgzMiTNRXuK4joPxnVfCI5mVGqgfKBGI1xpnhCY=";
  };

  sourceRoot = "source/cmd/otelcontribcol";
  vendorHash = "sha256-fOxhSuHTtFniSxPoqXxHiAPZUZX6sJo3q5G6Y0xEkJ4=";

  ldflags = [
    "-s"
    "-w"
    "-X github.com/open-telemetry/opentelemetry-collector-contrib/internal/otelcontribcore/internal/version.Version=v${version}"
  ];

  meta = with lib; {
    description = "OpenTelemetry Collector superset with additional community collectors";
    longDescription = ''
      The OpenTelemetry Collector offers a vendor-agnostic implementation on how
      to receive, process and export telemetry data. In addition, it removes the
      need to run, operate and maintain multiple agents/collectors in order to
      support open-source telemetry data formats (e.g. Jaeger, Prometheus, etc.)
      sending to multiple open-source or commercial back-ends. The Contrib
      edition provides aditional vendor specific receivers/exporters and/or
      components that are only useful to a relatively small number of users and
      is multiple times larger as a result.
    '';
    homepage = "https://github.com/open-telemetry/opentelemetry-collector-contrib";
    changelog = "https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/v${version}/CHANGELOG.md";
    license = licenses.asl20;
    maintainers = with maintainers; [ uri-canva jk Intuinewin ];
    mainProgram = "otelcontribcol";
  };
}
