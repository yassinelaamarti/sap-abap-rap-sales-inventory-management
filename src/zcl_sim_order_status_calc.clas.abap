CLASS zcl_sim_order_status_calc DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_sadl_exit_calc_element_read.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.


CLASS zcl_sim_order_status_calc IMPLEMENTATION.

  METHOD if_sadl_exit_calc_element_read~get_calculation_info.
    et_requested_orig_elements = VALUE #( ( `STATUS` ) ).
  ENDMETHOD.


  METHOD if_sadl_exit_calc_element_read~calculate.

    DATA lt_orders TYPE STANDARD TABLE OF zsim_c_salesorder WITH DEFAULT KEY.
    lt_orders = CORRESPONDING #( it_original_data ).

    LOOP AT lt_orders ASSIGNING FIELD-SYMBOL(<order>).
      CASE <order>-Status.
        WHEN 'N'.
          <order>-StatusText        = 'New'.
          <order>-StatusCriticality = 0.
        WHEN 'C'.
          <order>-StatusText        = 'Confirmed'.
          <order>-StatusCriticality = 2.
        WHEN 'S'.
          <order>-StatusText        = 'Shipped'.
          <order>-StatusCriticality = 3.
        WHEN 'X'.
          <order>-StatusText        = 'Cancelled'.
          <order>-StatusCriticality = 1.
        WHEN OTHERS.
          <order>-StatusText        = <order>-Status.
          <order>-StatusCriticality = 0.
      ENDCASE.
    ENDLOOP.

    ct_calculated_data = CORRESPONDING #( lt_orders ).

  ENDMETHOD.

ENDCLASS.
