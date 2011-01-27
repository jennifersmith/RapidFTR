require 'rubygems'
require 'sunspot' # In the real world we should probably vendor this.
require 'spec_helper'

describe "Solar" do  
  before :each do
      fields = [Field.new_text_field("name"),Field.new_text_field("last_known_location")]
      FormSection.stub!(:all_enabled_child_fields).and_return(fields)
  end
  class ChildInstanceAccessor < Sunspot::Adapters::InstanceAdapter
    
    def id
      @instance.id
    end
  end
  
  class ChildDataAccessor < Sunspot::Adapters::DataAccessor 
    def load(id)
      Child.get(id)
    end
  end
  
  Sunspot::Adapters::DataAccessor.register(ChildDataAccessor, Child)
  Sunspot::Adapters::InstanceAdapter.register(ChildInstanceAccessor, Child)
  
  Sunspot.setup(Child) do
    text :name
    string :name
  end
  
  def search_with_string(input)
    input = input.downcase
    Sunspot.search(Child) do 
      fulltext("name_text:#{input}* OR name_text:#{input}~0.01")
      adjust_solr_params do |params| 
        params[:defType] = "lucene"
      end 
    end
  end

  it "should match on the first part of a child's first name" do
    Sunspot.remove_all(Child)
    child1 = Child.create('last_known_location' => "New York", "name" => "Mohammed Smith")
    child2 = Child.create('last_known_location' => "New York", "name" => "Muhammed Jones")
    child3 = Child.create('last_known_location' => "New York", "name" => "Muhammad Brown")
    child4 = Child.create('last_known_location' => "New York", "name" => "Ammad Brown")
    Sunspot.index([child1, child2, child3, child4])
    Sunspot.commit    
    
    search = search_with_string("Muha")
    
    search.results.map(&:name).sort.should == ["Muhammad Brown", "Muhammed Jones"]
  end

  it "should match on the first part of a child's last name" do
    Sunspot.remove_all(Child)
    child1 = Child.create('last_known_location' => "New York", "name" => "Mohammed Smith")
    child2 = Child.create('last_known_location' => "New York", "name" => "Muhammed Jones")
    child3 = Child.create('last_known_location' => "New York", "name" => "Muhammad Brown")
    child4 = Child.create('last_known_location' => "New York", "name" => "Ammad Brown")
    Sunspot.index([child1, child2, child3, child4])
    Sunspot.commit    
    
    search = search_with_string("Bro")
    
    search.results.map(&:name).sort.should == ["Ammad Brown", "Muhammad Brown"]
  end

  it "should match on approximate spelling of a child's entire first name" do
    Sunspot.remove_all(Child)
    child1 = Child.create('last_known_location' => "New York", "name" => "Mohammed Smith")
    child2 = Child.create('last_known_location' => "New York", "name" => "Muhammed Jones")
    child3 = Child.create('last_known_location' => "New York", "name" => "Muhammad Brown")
    child4 = Child.create('last_known_location' => "New York", "name" => "Ammad Brown")
    Sunspot.index([child1, child2, child3, child4])
    Sunspot.commit    
    
    search = search_with_string("Mohamed")
    
    search.results.map(&:name).sort.should == ["Mohammed Smith", "Muhammad Brown", "Muhammed Jones"]
  end

  it "should support partial reindexing" do
    Sunspot.remove_all(Child)
    child1 = Child.create('last_known_location' => "New York", "name" => "Mohammed Smith")
    child2 = Child.create('last_known_location' => "New York", "name" => "Muhammed Jones")
    child3 = Child.create('last_known_location' => "New York", "name" => "Muhammad Brown")
    child4 = Child.create('last_known_location' => "New York", "name" => "Ammad Brown")
    Sunspot.index([child1, child2])
    Sunspot.commit    
    
    Sunspot.index([child3, child4])
    Sunspot.commit    

    search = search_with_string("Mohamed")
    
    search.results.map(&:name).sort.should == ["Mohammed Smith", "Muhammad Brown", "Muhammed Jones"]
  end
  
  it "should load child instance" do
    child = Child.create('last_known_location' => "New York")
    
    accessor = ChildInstanceAccessor.new child
    accessor.id.should == child.id
  end
  
  it "should load_all child instances" do
    child = Child.create('last_known_location' => "New York")
    
    accessor = ChildDataAccessor.new Child
    accessor.load(child.id).should == child
  end
   describe "Child.search" do
    before :each do
      Sunspot.remove_all(Child)
    end
    
    it "should return empty array if search is not valid" do
      search = mock("search", :query => "", :valid? => false)
      Child.search(search).should == []      
    end
    
    it "should return empty array for no match" do
      search = mock("search", :query => "Nothing", :valid? => true)
      Child.search(search).should == []
    end

    it "should return an exact match" do
      create_child("Exact")
      search = mock("search", :query => "Exact", :valid? => true)
      Child.search(search).map(&:name).should == ["Exact"]
    end
  
    it "should return a match that starts with the query" do
      create_child("Starts With")
      search = mock("search", :query => "Star", :valid? => true)      
      Child.search(search).map(&:name).should == ["Starts With"]
    end
    
    it "should return a fuzzy match" do
      create_child("timithy")
      create_child("timothy")
      search = mock("search", :query => "timothy", :valid? => true)      
      Child.search(search).map(&:name).should =~ ["timithy", "timothy"]
    end
    
    it "should search by exact match for unique id" do
      uuid = UUIDTools::UUID.random_create.to_s
      Child.create("name" => "kev", :unique_identifier => uuid, "last_known_location" => "new york")
      Child.create("name" => "kev", :unique_identifier => UUIDTools::UUID.random_create, "last_known_location" => "new york")
      search = mock("search", :query => uuid, :valid? => true)      
      results = Child.search(search)
      results.length.should == 1
      results.first[:unique_identifier].should == uuid
    end
    
    it "should match more than one word" do
      create_child("timothy cochran") 
      search = mock("search", :query => "timothy cochran", :valid? => true)           
      Child.search(search).map(&:name).should =~ ["timothy cochran"]
    end
    
    it "should match more than one word with fuzzy search" do
      create_child("timothy cochran")      
      search = mock("search", :query => "timithy cichran", :valid? => true)           
      Child.search(search).map(&:name).should =~ ["timothy cochran"]
    end
    
    it "should match more than one word with starts with" do
      create_child("timothy cochran")
      search = mock("search", :query => "timo coch", :valid? => true)                 
      Child.search(search).map(&:name).should =~ ["timothy cochran"]
    end
    
    # it "should search across name and unique identifier" do
    #   Child.create("name" => "John Doe", "last_known_location" => "new york", "unique_identifier" => "ABC123")
    #   
    #   Child.search("ABC123").map(&:name).should == ["John Doe"]
    # end
    
    def create_child(name)
      Child.create("name" => name, "last_known_location" => "new york")
    end 
  end
end
