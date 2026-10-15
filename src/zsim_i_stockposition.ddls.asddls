@EndUserText.label: 'Stock position per product and plant'
@AccessControl.authorizationCheck: #NOT_REQUIRED

define view entity ZSIM_I_STOCKPOSITION
  as select from zsim_stock   as stock
    inner join   zsim_product as product
      on product.product_id = stock.product_id
    left outer join ZSIM_I_STOCKCOMMITTED as committed
      on  committed.ProductId = stock.product_id
      and committed.PlantId   = stock.plant_id
{
  key stock.product_id       as ProductId,
  key stock.plant_id         as PlantId,

      product.product_name   as ProductName,
      stock.quantity_on_hand as QuantityOnHand,

      cast( coalesce( committed.CommittedQty, cast( 0 as abap.dec( 13, 3 ) ) )
            as abap.dec( 13, 3 ) ) as CommittedQty,

      cast( stock.quantity_on_hand
            - coalesce( committed.CommittedQty, cast( 0 as abap.dec( 13, 3 ) ) )
            as abap.dec( 13, 3 ) ) as AvailableStock,

      product.reorder_threshold as ReorderThreshold
}
