@EndUserText.label: 'Stock by Plant'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.ignorePropagatedAnnotations: true

define view entity ZSIM_I_STOCK
  as select from zsim_stock
  association to parent ZSIM_I_PRODUCT as _Product on $projection.ProductId = _Product.ProductId
  association [1..1] to ZSIM_I_PLANT   as _Plant   on $projection.PlantId   = _Plant.PlantId
  composition [0..*] of ZSIM_I_STOCKMOVEMENT as _Movements
{
  key product_id        as ProductId,
  key plant_id          as PlantId,
      quantity_on_hand  as QuantityOnHand,
      last_updated_at   as LastUpdatedAt,

      @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_SIM_STOCK_CALC'
      cast( 0 as abap.dec( 13,3 ) ) as AvailableStock,

      @ObjectModel.virtualElementCalculatedBy: 'ABAP:ZCL_SIM_STOCK_CALC'
      cast( 0 as abap.int1 ) as RiskCriticality,

      /* Associations */
      _Product,
      _Plant,
      _Movements
}
