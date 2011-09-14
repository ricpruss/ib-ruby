require 'ib-ruby/models/model'

# TODO: Implement equals() according to the criteria in IB's Java client.

module IB::Models
  class Contract < Model

    # Valid security types (sec_type attribute)
    SECURITY_TYPES = {:stock => "STK",
                      :option => "OPT",
                      :future => "FUT",
                      :index => "IND",
                      :futures_option => "FOP",
                      :forex => "CASH",
                      :bag => "BAG"}

    BAG_SEC_TYPE = "BAG"

    # Fields are Strings unless noted otherwise
    attr_accessor :con_id, # int: The unique contract identifier.
                  :symbol, # This is the symbol of the underlying asset.
                  :sec_type, # Security type. Valid values are: SECURITY_TYPES
                  :expiry, # The expiration date. Use the format YYYYMM.
                  :strike, # double: The strike price.
                  :right, # Specifies a Put or Call. Valid values are: P, PUT, C, CALL
                  :multiplier, # Specifies a future or option contract multiplier
                  #              (only necessary when multiple possibilities exist)

                  :exchange, # The order destination, such as Smart.
                  :currency, # Ambiguities MAY require that currency field be specified,
                  #            for example, when SMART is the exchange and IBM is being
                  #            requested (IBM can trade in GBP or USD).

                  :local_symbol, # Local exchange symbol of the underlying asset
                  :primary_exchange, # pick a non-aggregate (ie not the SMART) exchange
                  #                    that the contract trades on.  DO NOT SET TO SMART.

                  :include_expired, # If set to true, contract details requests and historical
                  #         data queries can be performed pertaining to expired contracts.
                  #         Note: Historical data queries on expired contracts are
                  #         limited to the last year of the contracts life, and are
                  #         only supported for expired futures contracts.
                  #         This field can NOT be set to true for orders.

                  :sec_id_type, # Security identifier, when querying contract details or
                  #               when placing orders. Supported identifiers are:
                  #               -  ISIN (Example: Apple: US0378331005)
                  #               -  CUSIP (Example: Apple: 037833100)
                  #               -  SEDOL (6-AN + check digit. Example: BAE: 0263494)
                  #               -  RIC (exchange-independent RIC Root and exchange-
                  #                  identifying suffix. Example: AAPL.O for Apple on NASDAQ.)
                  :sec_id, # Unique identifier of the given secIdType.

                  # COMBOS
                  :combo_legs_description, # received in open order for all combos
                  :combo_legs, # Dynamic memory structure used to store the leg
                  #              definitions for this contract.

                  :under_comp # public UnderComp m_underComp // delta neutral

    # NB :description field is entirely local to ib-ruby, and not part of TWS.
    # You can use it to store whatever arbitrary data you want.
    attr_accessor :description

    def initialize opts = {}
      # Assign defaults to properties first!
      @con_id = 0
      @strike = 0
      @sec_type = ''
      @include_expired = false
      @combo_legs = Array.new

      super opts
    end

    # some protective filters
    def primary_exchange=(x)
      x.upcase! if x.is_a?(String)

      # per http://chuckcaplan.com/twsapi/index.php/Class%20Contract
      raise(ArgumentError.new("Don't set primary_exchange to smart")) if x == "SMART"

      @primary_exchange = x
    end

    def right=(x)
      x.upcase! if x.is_a?(String)
      x = nil if !x.nil? && x.empty?
      raise(ArgumentError.new("Invalid right \"#{x}\" (must be one of PUT, CALL, P, C)")) unless x.nil? || ["PUT", "CALL", "P", "C", "0"].include?(x)
      @right = x
    end

    def expiry=(x)
      x = x.to_s
      if (x.nil? || !(x =~ /\d{6,8}/)) and !x.empty? then
        raise ArgumentError.new("Invalid expiry \"#{x}\" (must be in format YYYYMM or YYYYMMDD)")
      end
      @expiry = x
    end

    def sec_type=(x)
      x = nil if !x.nil? && x.empty?
      raise(ArgumentError.new("Invalid security type \"#{x}\" (see SECURITY_TYPES constant in Contract class for valid types)")) unless x.nil? || SECURITY_TYPES.values.include?(x)
      @sec_type = x
    end

    def reset
      @combo_legs = Array.new
      @strike = 0
    end

    # This returns an Array of data from the given contract, in standard format.
    # Different messages serialize contracts differently. Go figure.
    # Note that it does not include the combo legs.
    def serialize(type = :long)
      [symbol,
       sec_type,
       expiry,
       strike,
       right,
       multiplier,
       exchange] +
          (type == :long ? [primary_exchange] : []) +
          [currency,
           local_symbol]
    end

    # @Legacy
    def serialize_long(version)
      serialize(:long)
    end

    # @Legacy
    def serialize_short(version)
      serialize(:short)
    end

    # This produces a string uniquely identifying this contract, in the format used
    # for command line arguments in the IB-Ruby examples. The format is:
    #
    #    symbol:security_type:expiry:strike:right:multiplier:exchange:primary_exchange:currency:local_symbol
    #
    # Fields not needed for a particular security should be left blank
    # (e.g. strike and right are only relevant for options.)
    #
    # For example, to query the British pound futures contract trading on Globex
    # expiring in September, 2008, the string is:
    #
    #    GBP:FUT:200809:::62500:GLOBEX::USD:
    def serialize_ib_ruby(version)
      serialize.join(":")
    end

    # This returns a Contract initialized from the serialize_ib_ruby format string.
    def self.from_ib_ruby(string)
      c = Contract.new
      c.symbol, c.sec_type, c.expiry, c.strike, c.right, c.multiplier,
          c.exchange, c.primary_exchange, c.currency, c.local_symbol = string.split(":")
      c
    end

    def serialize_under_comp(*args)
      raise "Unimplemented"
      # EClientSocket.java, line 471:
      #if (m_serverVersion >= MIN_SERVER_VER_UNDER_COMP) {
      # 	   if (contract.m_underComp != null) {
      # 		   UnderComp underComp = contract.m_underComp;
      # 		   send( true);
      # 		   send( underComp.m_conId);
      # 		   send( underComp.m_delta);
      # 		   send( underComp.m_price);
      # 	   }
    end

    def serialize_algo(*args)
      raise "Unimplemented"
      #if (m_serverVersion >= MIN_SERVER_VER_ALGO_ORDERS) {
      #  send( order.m_algoStrategy);
      #  if( !IsEmpty(order.m_algoStrategy)) {
      #    java.util.Vector algoParams = order.m_algoParams;
      #    int algoParamsCount = algoParams == null ? 0 : algoParams.size();
      #    send( algoParamsCount);
      #    if( algoParamsCount > 0) {
      #      for( int i = 0; i < algoParamsCount; ++i) {
      #        TagValue tagValue = (TagValue)algoParams.get(i);
      #        send( tagValue.m_tag);
      #        send( tagValue.m_value);
      #      }
      #    }
      #  }
      #}
    end

    # Some messages send open_close too, some don't. WTF.
    def serialize_combo_legs(type = :short)
      # No idea what "BAG" means. Copied from the Java code.
      return [] unless sec_type.upcase == "BAG"
      return [0] if combo_legs.empty? || combo_legs.nil?
      [combo_legs.size,
       combo_legs.map { |leg| leg.serialize(type) }]
    end

    def to_human
      "<IB-Contract: " + [symbol, expiry, sec_type, strike, right, exchange, currency].join("-") + "}>"
    end

    def to_short
      "#{symbol}#{expiry}#{strike}#{right}#{exchange}#{currency}"
    end

    def to_s
      to_human
    end

    # Contract::Details is an internal class of Contract, as it should be
    class Details < Model

      # All fields Strings, unless specified otherwise
      attr_accessor :summary, # Contract: reference!
                    :market_name, # The market name for this contract.
                    :trading_class, # The trading class name for this contract.
                    :min_tick, # double: The minimum price tick.
                    :price_magnifier, # int: Allows execution and strike prices to be
                    #     reported consistently with market data, historical data and the
                    #     order price: Z on LIFFE is reported in index points, not GBP.

                    :order_types, #     The list of valid order types for this contract.
                    :valid_exchanges, # The list of exchanges this contract is traded on.
                    :under_con_id, # int: The underlying contract ID.
                    :long_name, #         Descriptive name of the asset.
                    :contract_month, # Typically the contract month of the underlying for a futures contract.

                    # The industry classification of the underlying/product:
                    :industry, #    Wide industry. For example, Financial.
                    :category, #    Industry category. For example, InvestmentSvc.
                    :subcategory, # Subcategory. For example, Brokerage.
                    :time_zone, # The ID of the time zone for the trading hours of the
                    #             product. For example, EST.
                    :trading_hours, # The trading hours of the product. For example:
                    #                 20090507:0700-1830,1830-2330;20090508:CLOSED.
                    :liquid_hours, #  The liquid trading hours of the product. For example,
                    #                 20090507:0930-1600;20090508:CLOSED.

                    # Bond values:
                    :cusip, # The nine-character bond CUSIP or the 12-character SEDOL.
                    :ratings, # Credit rating of the issuer. Higher credit rating generally
                    #           indicates a less risky investment. Bond ratings are from
                    #           Moody's and S&P respectively.
                    :desc_append, # Additional descriptive information about the bond.
                    :bond_type, #   The type of bond, such as "CORP."
                    :coupon_type, # The type of bond coupon.
                    :callable, # bool: Can be called by the issuer under certain conditions. default false
                    :puttable, # bool: Can be sold back to the issuer under certain conditions. default false
                    :coupon, # double: The interest rate used to calculate the amount you
                    #          will receive in interest payments over the year. default 0
                    :convertible, # bool: Can be converted to stock under certain conditions. default false
                    :maturity, # The date on which the issuer must repay bond face value
                    :issue_date, # The date the bond was issued.
                    :next_option_date, # only if bond has embedded options.
                    :next_option_type, # only if bond has embedded options.
                    :next_option_partial, # bool: # only if bond has embedded options. default false
                    :notes # Additional notes, if populated for the bond in IB's database

      def initialize opts = {}
        @summary = Contract.new
        @under_con_id = 0
        @min_tick = 0
        @callable = false
        @puttable = false
        @coupon = 0
        @convertible = false
        @next_option_partial = false

        super opts
      end
    end # class Details

    # ComboLeg is an internal class of Contract, as it should be
    class ComboLeg < Model
      # // open/close leg value is same as combo
      # Specifies whether the order is an open or close order. Valid values are:
      SAME = 0 #  Same as the parent security. The only option for retail customers.
      OPEN = 1 #  Open. This value is only valid for institutional customers.
      CLOSE = 2 # Close. This value is only valid for institutional customers.
      UNKNOWN = 3


      attr_accessor :con_id, # int: The unique contract identifier specifying the security.
                    :ratio, # int: Select the relative number of contracts for the leg you
                    #              are constructing. To help determine the ratio for a
                    #              specific combination order, refer to the Interactive
                    #              Analytics section of the User's Guide.

                    :action, # String: BUY/SELL/SSHORT/SSHORTX
                    #          The side (buy or sell) for the leg you are constructing.
                    :exchange, # String: exchange to which the complete combination
                    #            order will be routed.
                    :open_close, # int: Specifies whether the order is an open or close order.
                    #              Valid values: ComboLeg::SAME/OPEN/CLOSE/UNKNOWN

                    # For institutional customers only! For stock legs when doing short sale
                    :short_sale_slot, # int: 0 - retail, 1 = clearing broker, 2 = third party
                    :designated_location, # String: Only for shortSaleSlot == 2.
                    #                    Otherwise leave blank or orders will be rejected.
                    :exempt_code # int: ?

      def initialize opts = {}
        @con_id = 0
        @ratio = 0
        @open_close = 0
        @short_sale_slot = 0
        @designated_location = ''
        @exempt_code = -1

        super opts
      end

      # Some messages include open_close, some don't. wtf.
      def serialize(type = :short)
        [con_id,
         ratio,
         action,
         exchange] +
            type == :short ? [] : [open_close,
                                   short_sale_slot,
                                   designated_location,
                                   exempt_code]
      end
    end # ComboLeg

  end # class Contract
end # module IB::Models