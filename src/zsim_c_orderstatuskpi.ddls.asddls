@EndUserText.label: 'Orders by Status and Plant'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true

define view entity ZSIM_C_ORDERSTATUSKPI
  as select from ZSIM_I_ORDERSTATUSBASE
{
  key Status,
  key PlantId,
  key Currency,
      StatusText,
      StatusCriticality,
      StatusOrder,

      sum( OrderCount ) as OrderCount,

      @Semantics.amount.currencyCode: 'Currency'
      sum( TotalAmount ) as TotalAmount
}
group by
  Status,
  PlantId,
  Currency,
  StatusText,
  StatusCriticality,
  StatusOrder
