CLASS zcl_sim_data_setup DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS zcl_sim_data_setup IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

    " 1. Clear existing data (for repeatable test runs)
    DELETE FROM zsim_so_item.
    DELETE FROM zsim_so_item_d.
    DELETE FROM zsim_so_d.
    DELETE FROM zsim_so.
    DELETE FROM zsim_stock_mvt.
    DELETE FROM zsim_stock.
    DELETE FROM zsim_product.
    DELETE FROM zsim_customer.
    DELETE FROM zsim_plant.
    COMMIT WORK.

    " 2. Plants
    INSERT zsim_plant FROM TABLE @( VALUE #(
      ( client = sy-mandt plant_id = '1000' plant_name = 'Paris Warehouse'  city = 'Paris'  country_code = 'FR' )
      ( client = sy-mandt plant_id = '2000' plant_name = 'Lyon Warehouse'   city = 'Lyon'   country_code = 'FR' )
    ) ).

    " 3. Products (with varying reorder thresholds)
    INSERT zsim_product FROM TABLE @( VALUE #(
      ( client = sy-mandt product_id = 'P-0001' product_name = 'Wireless Mouse'      unit_price = '19.99'  currency = 'EUR' reorder_threshold = '20' )
      ( client = sy-mandt product_id = 'P-0002' product_name = 'Mechanical Keyboard' unit_price = '79.99'  currency = 'EUR' reorder_threshold = '15' )
      ( client = sy-mandt product_id = 'P-0003' product_name = '27-inch Monitor'     unit_price = '249.00' currency = 'EUR' reorder_threshold = '5'  )
      ( client = sy-mandt product_id = 'P-0004' product_name = 'USB-C Hub'           unit_price = '34.50'  currency = 'EUR' reorder_threshold = '30' )
      ( client = sy-mandt product_id = 'P-0005' product_name = 'Webcam HD'           unit_price = '45.00'  currency = 'EUR' reorder_threshold = '10' )
    ) ).

    " 4. Customers
    INSERT zsim_customer FROM TABLE @( VALUE #(
      ( client = sy-mandt customer_id = 'C-0001' customer_name = 'Acme Corp'      city = 'Paris'     country_code = 'FR' )
      ( client = sy-mandt customer_id = 'C-0002' customer_name = 'Global Tech'    city = 'Lyon'      country_code = 'FR' )
      ( client = sy-mandt customer_id = 'C-0003' customer_name = 'Nova Solutions' city = 'Marseille' country_code = 'FR' )
    ) ).

    " 5. Stock (some intentionally low to trigger the "at risk" flag)
    INSERT zsim_stock FROM TABLE @( VALUE #(
      ( client = sy-mandt product_id = 'P-0001' plant_id = '1000' quantity_on_hand = '50'  last_updated_at = utclong_current( ) )
      ( client = sy-mandt product_id = 'P-0002' plant_id = '1000' quantity_on_hand = '12'  last_updated_at = utclong_current( ) )
      ( client = sy-mandt product_id = 'P-0003' plant_id = '1000' quantity_on_hand = '3'   last_updated_at = utclong_current( ) )
      ( client = sy-mandt product_id = 'P-0004' plant_id = '2000' quantity_on_hand = '100' last_updated_at = utclong_current( ) )
      ( client = sy-mandt product_id = 'P-0005' plant_id = '2000' quantity_on_hand = '8'   last_updated_at = utclong_current( ) )
    ) ).

        " Historique : une réception initiale par ligne de stock
    TRY.
        SELECT product_id, plant_id, quantity_on_hand
          FROM zsim_stock
          INTO TABLE @DATA(stock_rows).

        DATA movements TYPE STANDARD TABLE OF zsim_stock_mvt WITH DEFAULT KEY.

        LOOP AT stock_rows INTO DATA(stock_row).
          APPEND VALUE #(
            client        = sy-mandt
            movement_id   = cl_system_uuid=>create_uuid_x16_static( )
            product_id    = stock_row-product_id
            plant_id      = stock_row-plant_id
            movement_type = 'Receipt'
            quantity      = stock_row-quantity_on_hand
            stock_after   = stock_row-quantity_on_hand
            reference     = 'Initial stock'
            created_by    = cl_abap_context_info=>get_user_technical_name( )
            created_at    = utclong_current( ) ) TO movements.
        ENDLOOP.

        INSERT zsim_stock_mvt FROM TABLE @movements.
        COMMIT WORK.
      CATCH cx_uuid_error INTO DATA(uuid_error).
        out->write( uuid_error->get_text( ) ).
    ENDTRY.

    COMMIT WORK.
    out->write( `Reference data (Plant, Product, Customer, Stock) inserted.` ).

    " 6. Sales Orders + Items (direct INSERT for test data simplicity)
    INSERT zsim_so FROM TABLE @( VALUE #(
      ( client = sy-mandt order_id = 'SO-0001' customer_id = 'C-0001' plant_id = '1000'
        order_date = cl_abap_context_info=>get_system_date( ) status = 'N'
        total_amount = '597.95' currency = 'EUR' )
      ( client = sy-mandt order_id = 'SO-0002' customer_id = 'C-0002' plant_id = '2000'
        order_date = cl_abap_context_info=>get_system_date( ) status = 'N'
        total_amount = '135.00' currency = 'EUR' )
    ) ).

    INSERT zsim_so_item FROM TABLE @( VALUE #(
      ( client = sy-mandt order_id = 'SO-0001' item_number = '0010' product_id = 'P-0001'
        plant_id = '1000' quantity = '5'
        net_amount = '99.95'  currency = 'EUR' )
      ( client = sy-mandt order_id = 'SO-0001' item_number = '0020' product_id = 'P-0003'
        plant_id = '1000' quantity = '2'
        net_amount = '498.00' currency = 'EUR' )
      ( client = sy-mandt order_id = 'SO-0002' item_number = '0010' product_id = 'P-0005'
        plant_id = '2000' quantity = '3'
        net_amount = '135.00' currency = 'EUR' )
    ) ).

    COMMIT WORK.
    out->write( `Sales orders inserted directly.` ).

  ENDMETHOD.

ENDCLASS.
