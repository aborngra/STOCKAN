BEGIN
  market_prices_bl.import_marketprices(p_symbol => 'DBK.DE');
END;
/

BEGIN
  market_prices_bl.import_marketprices;
END;
/