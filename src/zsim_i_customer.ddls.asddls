@EndUserText.label: 'Customer'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.ignorePropagatedAnnotations: true

define root view entity ZSIM_I_CUSTOMER
  as select from zsim_customer
{
  key customer_id    as CustomerId,
      customer_name  as CustomerName,
      city           as City,
      country_code   as CountryCode
}
