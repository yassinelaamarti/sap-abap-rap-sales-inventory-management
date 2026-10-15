CLASS zcl_sim_stock_calc DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_sadl_exit_calc_element_read.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.


CLASS zcl_sim_stock_calc IMPLEMENTATION.

  METHOD if_sadl_exit_calc_element_read~get_calculation_info.
    et_requested_orig_elements = VALUE #(
      ( `PRODUCTID` )
      ( `PLANTID` )
      ( `QUANTITYONHAND` )
    ).
  ENDMETHOD.


  METHOD if_sadl_exit_calc_element_read~calculate.

    DATA lt_stock TYPE STANDARD TABLE OF zsim_i_stock WITH DEFAULT KEY.

    lt_stock = CORRESPONDING #( it_original_data ).
    CHECK lt_stock IS NOT INITIAL.

    " 1. Quantités engagées : commandes New ou Confirmed, groupées par produit/site
    "    (une commande Shipped a déjà fait baisser le stock physique, une Cancelled ne compte plus)
    SELECT item~product_id      AS product_id,
           so~plant_id          AS plant_id,
           SUM( item~quantity ) AS qty
      FROM zsim_so AS so
      INNER JOIN zsim_so_item AS item
        ON item~order_id = so~order_id
      WHERE so~status IN ( 'N', 'C' )
      GROUP BY item~product_id, so~plant_id
      INTO TABLE @DATA(lt_committed).

    " 2. Seuils de réapprovisionnement
    SELECT product_id, reorder_threshold
      FROM zsim_product
      FOR ALL ENTRIES IN @lt_stock
      WHERE product_id = @lt_stock-ProductId
      INTO TABLE @DATA(lt_thresholds).

    " 3. Calcul ligne par ligne (sans accès base)
    LOOP AT lt_stock ASSIGNING FIELD-SYMBOL(<s>).

      DATA(lv_committed) = VALUE #( lt_committed[ product_id = <s>-ProductId
                                                  plant_id   = <s>-PlantId ]-qty OPTIONAL ).
      DATA(lv_threshold) = VALUE #( lt_thresholds[ product_id = <s>-ProductId ]-reorder_threshold OPTIONAL ).

      <s>-AvailableStock  = <s>-QuantityOnHand - lv_committed.
      <s>-RiskCriticality = COND #( WHEN <s>-AvailableStock < lv_threshold THEN 1 ELSE 3 ).

    ENDLOOP.

    ct_calculated_data = CORRESPONDING #( lt_stock ).

  ENDMETHOD.

ENDCLASS.
