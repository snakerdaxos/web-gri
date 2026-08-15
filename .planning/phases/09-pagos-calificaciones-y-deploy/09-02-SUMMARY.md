---
phase: 09-pagos-calificaciones-y-deploy
plan: 02
subsystem: backend-calificaciones
tags: [calificaciones, post-pago, promedio, public]
requires:
  - "09-01 (pago aprobado -> pedidos pagados; helpers conftest sandbox)"
provides:
  - "POST /cliente/calificaciones {pedido_id, estrellas, comentario} — solo pedidos pagados propios"
  - "GET /public/restaurantes + detalle con calificacion_promedio (AVG 1 decimal) + calificaciones_count"
affects:
  - "09-03 (app cliente: sheet calificacion + rating real en discover)"
key-files:
  created:
    - backend/app/schemas/calificacion.py
    - backend/app/services/calificacion_service.py
    - backend/tests/test_calificaciones.py
  modified:
    - backend/app/api/cliente.py
    - backend/app/services/public_service.py
metrics:
  duration: "~30 min (1 sesion interrumpida antes del SUMMARY)"
  tests-new: 9 (215 total)
  completed: 2026-08-14
---

# Phase 9 Plan 02: Calificaciones post-pago + promedio público Summary

## Goal
CALI-01 (calificar solo pedidos pagados) y CALI-02 (promedio visible en discover lista y detalle).

## Accomplished
- T1 (d8de7a2 + 8abb5ba): POST /cliente/calificaciones — 404 ajeno/inexistente, 409 ya calificado (UNIQUE), 422 estrellas fuera de rango, solo estado pagado (409 si no)
- T2 (996d614 + fb85eed): promedio AVG + COUNT en /public lista y detalle (null/0 sin calificaciones)
- Fix Rule 1 (1b4e7ab): time-bomb TZ en tests de reserva + residuo calificaciones

## Verification
- Suite 215/215 tras limpieza de residuo (calificaciones de corridas previas contaminaban el demo avg)
- Orden FK limpieza: calificacion -> pago_event -> pago -> pedido_item -> pedido -> sesion_mesa

## Commits
d8de7a2, 8abb5ba, 996d614, fb85eed, 1b4e7ab
