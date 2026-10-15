@EndUserText.label: 'Stock Risk'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true

define view entity ZSIM_C_STOCKRISK
  as select from ZSIM_I_STOCKPOSITION
{
  key ProductId,
  key PlantId,
      ProductName,

      cast( QuantityOnHand as abap.dec( 13, 0 ) ) as QuantityOnHand,
      cast( CommittedQty   as abap.dec( 13, 0 ) ) as CommittedQty,
      cast( AvailableStock as abap.dec( 13, 0 ) ) as AvailableStock,
      cast( AvailableStock as abap.dec( 13, 0 ) ) as StockLevel,

      ReorderThreshold,

      cast( case
              when AvailableStock <= 0                then 'Out of stock'
              when AvailableStock < ReorderThreshold  then 'At risk'
              else 'OK'
            end as abap.char( 12 ) ) as RiskStatus,

      cast( case
              when AvailableStock <= 0                then 1
              when AvailableStock < ReorderThreshold  then 2
              else 3
            end as abap.int1 ) as RiskCriticality,

      cast( case
              when ReorderThreshold > 0
              then division( AvailableStock * 100, ReorderThreshold, 2 )
              else 100
            end as abap.dec( 9, 2 ) ) as CoveragePct,

      cast( case
              when AvailableStock < ReorderThreshold
              then ReorderThreshold - AvailableStock
              else 0
            end as abap.dec( 13, 0 ) ) as ShortfallQty
}
