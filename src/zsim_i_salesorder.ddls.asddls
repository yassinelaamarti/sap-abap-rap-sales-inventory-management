@EndUserText.label: 'Sales Order'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.ignorePropagatedAnnotations: true

define root view entity ZSIM_I_SALESORDER
  as select from zsim_so
  association [0..1] to ZSIM_I_CUSTOMER as _Customer on $projection.CustomerId = _Customer.CustomerId
  association [0..1] to ZSIM_I_PLANT    as _Plant    on $projection.PlantId    = _Plant.PlantId
  composition [0..*] of ZSIM_I_SALESORDERITEM as _Items
{
  key order_id      as OrderId,
      customer_id   as CustomerId,
      plant_id      as PlantId,
      order_date    as OrderDate,
      status        as Status,

      @Semantics.amount.currencyCode: 'Currency'
      total_amount  as TotalAmount,
      currency      as Currency,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,

      /* Associations */
      _Customer,
      _Plant,
      _Items
}
