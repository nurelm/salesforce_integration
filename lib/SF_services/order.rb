module SFService
  class Order < Base
    def initialize(config)
      super("Opportunity", config)
    end

    def latest_updates(time = Time.now.utc.iso8601)
      since = time ? Time.parse(time).utc.iso8601 : Time.now.utc.iso8601

      line_fields = ["Quantity",
                     "UnitPrice",
                     "PricebookEntry.Product2.Name",
                     "PricebookEntry.Product2.ProductCode"]

      line_nested = "SELECT #{line_fields.join(", ")} FROM OpportunityLineItems"
      notes_nested = "SELECT Title, Body FROM Notes WHERE Title LIKE 'Payment%'"

      fields = ["Id",
                "Name",
                "Amount",
                "CloseDate",
                "LastModifiedDate",
                "Account.Id",
                "(#{line_nested})",
                "(#{notes_nested})"]

      fields = fields.push(custom_fields).flatten.join(", ")

      if config[:salesforce_order_filters].is_a? String
        mappings = JSON.parse(config[:salesforce_order_filters])[0]

        filters = mappings.each_with_object([]) do |pair, filters|
          filters.push "#{pair[0]} = '#{pair[1]}'"
        end
        constraints = filters.join(" AND ")
      end

      if constraints.empty?
        constraints = "LeadSource = 'Web' AND StageName = 'closed-won'"
      end

      filter = "LastModifiedDate > #{since} ORDER BY LastModifiedDate ASC LIMIT 100"

      salesforce.query("SELECT #{fields} FROM Opportunity WHERE #{constraints} AND #{filter}")
    end

    def find_opportunity_id_by_name(name)
      results = salesforce.query("SELECT Id FROM Opportunity WHERE Name = '#{name}' LIMIT 1")
      results.any? ? results.first.fetch('Id') : nil
    end

    def find(id)
      salesforce.find('Opportunity', id, 'Name')
    end

    def find_price_book_by_id(price_book_id)
      results = salesforce.query("select Id from PriceBook2 where Name = '#{price_book_id}'")
      results.any? ? results.first['Id'] : nil
    end

    def upsert!(order_attr = {})
      if opportunity_id = find_opportunity_id_by_name(order_attr.fetch 'Name')
        update! order_attr.merge(Id: opportunity_id)
        opportunity_id
      else
        create!(order_attr)
      end
    end

    def custom_fields
      @custom_fields ||= config[:salesforce_orders_fields].to_s.split(',')
    end
  end
end
