@EndUserText.label: 'Orders base for dashboard'
@AccessControl.authorizationCheck: #NOT_REQUIRED

define view entity ZSIM_I_ORDERSTATUSBASE
  as select from zsim_so
{
  key order_id as OrderId,
      status   as Status,
      plant_id as PlantId,

      cast( case status
              when 'N' then 'New'
              when 'C' then 'Confirmed'
              when 'S' then 'Shipped'
              when 'X' then 'Cancelled'
              else 'Unknown'
            end as abap.char( 20 ) ) as StatusText,

      cast( case status
              when 'N' then 0
              when 'C' then 2
              when 'S' then 3
              when 'X' then 1
              else 0
            end as abap.int1 ) as StatusCriticality,

      cast( case status
              when 'N' then 1
              when 'C' then 2
              when 'S' then 3
              when 'X' then 4
              else 9
            end as abap.int1 ) as StatusOrder,

      cast( 1 as abap.int4 ) as OrderCount,

      @Semantics.amount.currencyCode: 'Currency'
      total_amount as TotalAmount,
      currency     as Currency
}
