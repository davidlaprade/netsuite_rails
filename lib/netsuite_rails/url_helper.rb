module NetSuiteRails
  module UrlHelper

    # TODO create a xxx_netsuite_url helper generator

    def self.netsuite_url(record = self)
      prefix = "https://system#{".sandbox" if NetSuite::Configuration.sandbox}.netsuite.com/app"

      if record.class.to_s.start_with?('NetSuite::Records')
        record_class = record.class
        internal_id = record.internal_id
        is_custom_record = false
      else
        record_class = record.netsuite_record_class
        internal_id = record.netsuite_id
        is_custom_record = record.netsuite_custom_record?
      end

      # TODO support NS classes, should jump right to the list for the class

      # https://system.sandbox.netsuite.com/app/common/scripting/scriptrecordlist.nl
      # https://system.sandbox.netsuite.com/app/common/scripting/script.nl

      # dependent record links
      # https://system.na1.netsuite.com/core/pages/itemchildrecords.nl?id=12413&t=InvtItem%05ProjectCostCategory&rectype=-10
      # https://system.na1.netsuite.com/app/accounting/transactions/payments.nl?id=91964&label=Customer+Refund&type=custrfnd&alllinks=T

      if is_custom_record
        "#{prefix}/common/custom/custrecordentry.nl?id=#{internal_id}&rectype=#{record.class.netsuite_custom_record_type_id}"
      elsif [
        NetSuite::Records::InventoryItem,
        NetSuite::Records::NonInventorySaleItem,
        NetSuite::Records::AssemblyItem,
        NetSuite::Records::ServiceSaleItem,
        NetSuite::Records::DiscountItem,
      ].include?(record_class)
        "#{prefix}/common/item/item.nl?id=#{internal_id}"
      elsif record_class == NetSuite::Records::Task
        "#{prefix}/crm/calendar/task.nl?id=#{internal_id}"
      elsif record_class == NetSuite::Records::Roles
        "#{prefix}/setup/role.nl?id=#{internal_id}"
      elsif [
        NetSuite::Records::Contact,
        NetSuite::Records::Customer,
        NetSuite::Records::Vendor,
        NetSuite::Records::Partner,
        NetSuite::Records::Employee
      ].include?(record_class)
        "#{prefix}/common/entity/entity.nl?id=#{internal_id}"
      elsif [
        NetSuite::Records::SalesOrder,
        NetSuite::Records::Invoice,
        NetSuite::Records::CustomerRefund,
        NetSuite::Records::CashSale,
        NetSuite::Records::ItemFulfillment,
        NetSuite::Records::CustomerDeposit,
        NetSuite::Records::CustomerPayment,
        NetSuite::Records::CreditMemo
        ].include?(record_class)
        "#{prefix}/accounting/transactions/transaction.nl?id=#{internal_id}"
      end
    end

  end
end
