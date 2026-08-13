# UI v4 legacy → semantic migration table

This table is the admission contract for new v4 Presentation Adapters. It maps
legacy scene-shaped components to reusable Catalog components and keeps the
legacy renderer available until a corresponding golden comparison exists.

| Legacy component | v4 semantic target | View Model / fallback | Migration rule |
|---|---|---|---|
| `FoodChoices` | `ChoiceList` + `OptionCard` | `ui.option-collection` | `shop_id`/`shop_name` are mapped; missing required id/title is skipped. |
| `TrainOptions` | `JourneyOptionList` | `ui.journey-option-collection` | Required origin, destination and times must be present. |
| `FlightBoard` | `JourneyOptionList` | `ui.journey-option-collection` | Flight rows use the same journey contract as train rows. |
| `TravelOptions` | `JourneyOptionList` | `ui.journey-option-collection` | Mixed journey kind; provider fields remain provenance, not UI fields. |
| `InfoRows` | `KeyValueList` | `ui.key-value-group` | Only validated label/value pairs are emitted. |
| `SocialHub` | `MessageFeed` + `AccountStatus`/`StatusNotice` | `ui.message-feed` | Social posts map to sender/text; account state remains a separate semantic surface. |
| `ConfirmPanel` | `ApprovalPanel` | `ui.approval-model` | Confirmation is represented as an action offer; the adapter never executes it. |
| `ThinkingStream` | `ActivityFeed` | runtime overlay + activity model | Transient phase belongs to Runtime Overlay, not canonical layout. |
| `ErrorNotice` | `StatusNotice` | `ui.status-value` | Error tone is explicit and does not change the component family. |
| `ScheduleStack` | `Schedule`/`Timeline` | `ui.timeline` | Ordered events use timestamp/status fields; no provider-specific component. |
| `StripeReceivingAccountCard` | `AccountStatus` + optional `PaymentSummary` | extension only when required | Extension review is required if semantic fields cannot express the payment state. |

## Adapter rules

1. The adapter receives the original Tool Result and emits only a registered,
   versioned View Model envelope.
2. Missing required fields cause that item to be skipped; the adapter does not
   invent labels, actions, prices, or layout.
3. Provenance is copied into the envelope. `actionRefs` can only come from the
   host-issued offer map.
4. A generic structured result may use `ui.result-collection`; unknown shapes
   stay rejected instead of becoming arbitrary component JSON.

The table is a migration contract, not a claim that every target renderer or
golden snapshot is already complete.
