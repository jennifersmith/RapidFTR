module Searchable
  class DocumentInstanceAccessor < Sunspot::Adapters::InstanceAdapter
    def id
      @instance.id
    end
  end

  class DocumentDataAccessor < Sunspot::Adapters::DataAccessor
    def load(id)
      Child.get(id)
    end
  end

  def self.included(klass)
    klass.extend ClassMethods
    klass.class_eval do
      after_create :index_record
      after_update :index_record
      after_save :index_record

      def index_record
      	begin
					Child.ensure_solr_schema
					Sunspot.index!(self)
       	rescue Errno::ECONNREFUSED => error
          puts "***Problem indexing record for searching, is SOLR running? #{error.message}"
				end
				true
      end
    end
  end

  module ClassMethods
    def sunspot_search(query = "")

      build_solr_schema
      response = Sunspot.search(self) do
        fulltext(query)
        adjust_solr_params do |params|
          params[:defType] = "lucene"
          params[:qf] = nil
        end
      end
      response.results

    end
		def ensure_solr_schema
			build_solr_schema if Sunspot::Setup.for(Child).nil?
		end
		def build_solr_schema
			fields = ["unique_identifier"]  + Field.all_text_names
    	Sunspot.setup(Child) do
      	text *fields
    	end
		end
    def reindex!
      Sunspot.remove_all(self)
			build_solr_schema
      self.all.each { |record| Sunspot.index!(record) }
    end
  end

end
