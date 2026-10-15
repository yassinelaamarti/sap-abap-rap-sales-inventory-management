@EndUserText.label: 'Committed quantity per product and plant'
@AccessControl.authorizationCheck: #NOT_REQUIRED

define view entity ZSIM_I_STOCKCOMMITTED
  as select from zsim_so_item as item
    inner join   zsim_so      as so
      on so.order_id = item.order_id
{
  key item.product_id as ProductId,
  key so.plant_id     as PlantId,

      cast( sum( item.quantity ) as abap.dec( 13, 3 ) ) as CommittedQty
}
where so.status = 'N'
   or so.status = 'C'
group by
  item.product_id,
  so.plant_id
