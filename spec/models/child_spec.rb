require 'spec_helper'


describe Child do

  before do
    form_section = FormSection.new :unique_id => "basic_details"
    form_section.add_text_field("last_known_location")
    form_section.add_text_field("age")
    form_section.add_text_field("origin")
    form_section.add_field(Field.new_radio_button("gender", ["male", "female"]))
    form_section.add_field(Field.new_photo_upload_box("current_photo_key"))
    form_section.add_field(Field.new_audio_upload_box("recorded_audio"))

    FormSection.stub!(:all).and_return([form_section])
  end

  describe "update_properties_with_user_name" do
    it "should reple old properties with updated ones" do
      child = Child.new("name" => "Dave", "age" => "28", "last_known_location" => "London")
      new_properties = {"name" => "Dave", "age" => "35"}
      child.update_properties_with_user_name "some_user", nil, nil, new_properties
      child['age'].should == "35"
      child['name'].should == "Dave"
      child['last_known_location'].should == "London"
    end

    it "should not replace old properties when updated ones have nil value" do
      child = Child.new("origin" => "Croydon", "last_known_location" => "London")
      new_properties = {"origin" => nil, "last_known_location" => "Manchester"}
      child.update_properties_with_user_name "some_user", nil, nil, new_properties
      child['last_known_location'].should == "Manchester"
      child['origin'].should == "Croydon"
    end

    it "should populate last_updated_by field with the user_name who is updating" do
      child = Child.new
      child.update_properties_with_user_name "jdoe", nil, nil, {}
      child['last_updated_by'].should == 'jdoe'
    end

    it "should populate last_updated_at field with the time of the update" do
      current_time_in_utc = Time.parse("17 Jan 2010 19:05UTC")
      current_time = mock()
      Time.stub!(:now).and_return current_time
      current_time.stub!(:getutc).and_return current_time_in_utc
      child = Child.new
      child.update_properties_with_user_name "jdoe", nil, nil, {}
      child['last_updated_at'].should == "2010-01-17 19:05:00UTC"
    end

    it "should update attachments when there is a photo update" do
      current_time = Time.parse("Jan 17 2010 14:05:32")
      Time.stub!(:now).and_return current_time
      child = Child.new
      child.update_properties_with_user_name "jdoe", uploadable_photo, nil, {}
      child['_attachments']['photo-2010-01-17T140532']['data'].should_not be_blank
    end

    it "should not update attachments when the photo value is nil" do
      child = Child.new
      child.update_properties_with_user_name "jdoe", nil, nil, {}
      child['_attachments'].should be_blank
      child['current_photo_key'].should be_nil
    end

    it "should update attachment when there is audio update" do
      current_time = Time.parse("Jan 17 2010 14:05:32")
      Time.stub!(:now).and_return current_time
      child = Child.new
      child.update_properties_with_user_name "jdoe", nil, uploadable_audio, {}
      child['_attachments']['audio-2010-01-17T140532']['data'].should_not be_blank
    end

    it "should respond nil for photo when there is no photo associated with the child" do
      child = Child.new
      child.photo.should == nil
    end
    
    it "should do nothing when a zero byte photo is associated with the child" do
      child = Child.new
      child['current_photo_key'] = ""
      child.photo.should == nil
    end
  end
  
  describe "validation of custom fields" do
    it "should fail to validate if no fields are filled in and no photo/audio attached" do      
      child = Child.new
      stub_enabled_fields [Field.new(:type => 'numeric_field', :name => 'height', :display_name => "height")]
      child.should_not be_valid_for_create
      child.errors[:has_at_least_one_field_value].should == ["Please fill in at least one field or upload a file"]
    end
    it "should fail to validate if only no-defaulting radio " do      
      child = Child.new
      stub_enabled_fields [Field.new(:type => 'numeric_field', :name => 'height', :display_name => "height")]
      child.should_not be_valid_for_create
      child.errors[:has_at_least_one_field_value].should == ["Please fill in at least one field or upload a file"]
    end
    it "should validate numeric types" do
      stub_enabled_fields [Field.new(:type => 'numeric_field', :name => 'height', :display_name => "height")]
      child = Child.new
      child[:height] = "very tall"
      
      child.should_not be_valid
      child.errors.on(:height).should == ["height must be a valid number"]
    end
    
    it "should validate multiple numeric types" do
      stub_enabled_fields [
        Field.new(:type => Field::NUMERIC_FIELD, :name => 'height', :display_name => "height"),
        Field.new(:type => Field::NUMERIC_FIELD, :name => 'new_age', :display_name => "new age")]
        
      child = Child.new
      child[:height] = "very tall"
      child[:new_age] = "very old"
      
      child.should_not be_valid
      child.errors.on(:height).should == ["height must be a valid number"]
      child.errors.on(:new_age).should == ["new age must be a valid number"]
    end
    it "should disallow text field values to be more than 200 chars" do
      stub_enabled_fields [Field.new(:type => Field::TEXT_FIELD, :name => "name", :display_name => "Name"), 
           Field.new(:type => Field::CHECK_BOX, :name => "not_name")]
      child = Child.new :name => ('a' * 201)
      child.should_not be_valid
      child.errors[:name].should == ["Name cannot be more than 200 characters long"]
    end

    it "should disallow text area values to be more than 400,000 chars" do
      stub_enabled_fields [Field.new(:type => Field::TEXT_AREA, :name => "a_textfield", :display_name => "A textfield")]
      child = Child.new :a_textfield => ('a' * 400_001)
      child.should_not be_valid
      child.errors[:a_textfield].should == ["A textfield cannot be more than 400000 characters long"]
    end

    it "should allow text area values to be 400,000 chars" do
      stub_enabled_fields [Field.new(:type => Field::TEXT_AREA, :name => "a_textfield", :display_name => "A textfield")]
      child = Child.new :a_textfield => ('a' * 400_000)
      child.should be_valid
    end

    it "should disallow date fields not formatted as dd M yy" do
      FormSection.stub!(:all_enabled_child_fields =>
          [Field.new(:type => Field::DATE_FIELD, :name => "a_datefield", :display_name => "A datefield")])
      child = Child.new :a_datefield => ('2/27/2010')
      child.should_not be_valid
      child.errors[:a_datefield].should == ["A datefield must follow this format: 4 Feb 2010"]
    end

    it "should allow date fields formatted as dd M yy" do
      FormSection.stub!(:all_enabled_child_fields =>
          [Field.new(:type => Field::DATE_FIELD, :name => "a_datefield", :display_name => "A datefield")])
      child = Child.new :a_datefield => ('27 Feb 2010')
      child.should be_valid
    end

    it "should not validate fields that were not filled in" do
      FormSection.stub!(:all_enabled_child_fields =>
          [Field.new(:type => Field::TEXT_FIELD, :name => "name"),
           Field.new(:type => Field::TEXT_AREA, :name => "another")])
      Child.new(:name => nil).should be_valid
    end

    it "should pass numeric fields that are valid numbers to 1 dp" do
      stub_enabled_fields [Field.new(:type => Field::NUMERIC_FIELD, :name => "height")]
      Child.new(:height => "10.2").should be_valid
    end
    
    it "should disallow file formats that are not photo formats" do
      child = Child.new

      child.photo = uploadable_photo_gif
      child.should_not be_valid

      child.photo = uploadable_photo_bmp
      child.save.should == false

      child.photo = uploadable_photo
      child.save.should == true
    end
    
    it "should disallow file formats that are not supported audio formats" do
      child = Child.new

      child.audio = uploadable_photo_gif
      child.save.should == false

      child.audio = uploadable_audio_amr
      child.save.should == true
      
      child.audio = uploadable_audio_mp3
      child.save.should == true
      
      child.audio = uploadable_audio_wav
      child.save.should == false
      
      child.audio = uploadable_audio_ogg
      child.save.should == false
      
    end
    
    it "should disallow age that is not a number" do
      stub_enabled_fields  [Field.new(:type=>Field::NUMERIC_FIELD,:name=>"age")]
      child = Child.new({:age => "not num"})
      child.save.should == false
    end

    it "should disallow age less than 1" do
      stub_enabled_fields [Field.new(:type=>Field::NUMERIC_FIELD,:name=>"age")]
      child = Child.new({:age => "1"})
      child.save.should == true
      
      child = Child.new({:age => "0"})
      child.save.should == false
    end
    
    it "should disallow age greater than 99" do
      stub_enabled_fields [Field.new(:type=>Field::NUMERIC_FIELD,:name=>"age")]
      child = Child.new({:age => "99"})
      child.should be_valid
      
      child = Child.new({:age => "100"})
      child.should_not be_valid
    end
    
    it "should disallow age more than 1 dp" do
      stub_enabled_fields [Field.new(:type=>Field::NUMERIC_FIELD,:name=>"age")]
      child = Child.new({:age => "10.1"})
      child.save.should == true
      
      child = Child.new({:age => "10.11"})
      child.save.should == false
    end
    
    it "should allow blank age if at least one other field is filled" do
      stub_enabled_fields [Field.new(:type=>Field::NUMERIC_FIELD,:name=>"age"),Field.new(:type=>Field::TEXT_FIELD,:name=>"name")]      
      child = Child.new({:age => "", :name=>"Bob"})
      child.should be_valid
      child = Child.new({:age => nil, :name=>"Bob"})
      child.should be_valid
    end

    it "should show error message for age if not valid" do
      stub_enabled_fields [Field.new(:type=>Field::NUMERIC_FIELD,:name=>"age", :display_name=>"Age")]
      child = Child.new({:age => "not num"})
      child.save.should == false
      child.errors.on("age").should == ["Age must be a valid number"]
    end
    
    it "should show error message for age if out of range" do
      child = Child.new({:age => "200"})
      child.save.should == false
      child.errors.on("age").should == ["Age must be between 1 and 99"]
    end
    
    it "should disallow image file formats that are not png or jpg" do
      stub_enabled_fields  [Field.new(:type=>Field::PHOTO_UPLOAD_BOX,:name=>"photo", :display_name=>"Photo")]
      
      child = Child.new
      child.photo = uploadable_photo
      child.should be_valid

      child_with_invalid_image = Child.new
      child_with_invalid_image.photo = uploadable_text_file
      child_with_invalid_image.should_not be_valid
    end
  end

  describe "new_with_user_name" do
    it "should create regular child fields" do
      child = Child.new_with_user_name('jdoe', 'last_known_location' => 'London', 'age' => '6')
      child['last_known_location'].should == 'London'
      child['age'].should == '6'
    end

    it "should create a unique id" do
      UUIDTools::UUID.stub("random_create").and_return(12345)
      child = Child.new_with_user_name('jdoe', 'last_known_location' => 'London')
      child['unique_identifier'].should == "jdoelon12345"
    end

    it "should create a created_by field with the user name" do
      child = Child.new_with_user_name('jdoe', 'some_field' => 'some_value')
      child['created_by'].should == 'jdoe'
    end

    it "should create a created_at field with time of creation" do
      current_time_in_utc = Time.parse("14 Jan 2010 14:05UTC")
      current_time = mock()
      Time.stub!(:now).and_return current_time
      current_time.stub!(:getutc).and_return current_time_in_utc
      child = Child.new_with_user_name('some_user', 'some_field' => 'some_value')
      child['created_at'].should == "2010-01-14 14:05:00UTC"
    end
  end

  it "should create a unique id based on the last known location and the user name" do
    child = Child.new({'last_known_location'=>'london'})
    UUIDTools::UUID.stub("random_create").and_return(12345)
    child.create_unique_id("george")
    child["unique_identifier"].should == "georgelon12345"
  end

  it "should use a default location if last known location is empty" do
    child = Child.new({'last_known_location'=>nil})
    UUIDTools::UUID.stub("random_create").and_return(12345)
    child.create_unique_id("george")
    child["unique_identifier"].should == "georgexxx12345"
  end

  it "should downcase the last known location of a child before generating the unique id" do
    child = Child.new({'last_known_location'=>'New York'})
    UUIDTools::UUID.stub("random_create").and_return(12345)
    child.create_unique_id("george")
    child["unique_identifier"].should == "georgenew12345"
  end

  it "should append a five digit random number to the unique child id" do
    child = Child.new({'last_known_location'=>'New York'})
    UUIDTools::UUID.stub("random_create").and_return('12345abcd')
    child.create_unique_id("george")
    child["unique_identifier"].should == "georgenew12345"
  end

  it "should handle special characters in last known location when creating unique id" do
    pending "Seem to be having UTF-8 related problems - cv (talk to zk)"
    child = Child.new({'last_known_location'=> "\215\303\304n"})
    UUIDTools::UUID.stub("random_create").and_return('12345abcd')
    child.create_unique_id("george")
    child["unique_identifier"].should == "george\21512345"
  end

  describe "photo attachments" do
    it "should create a field with current_photo_key on creation" do
      current_time = Time.parse("Jan 20 2010 17:10:32")
      Time.stub!(:now).and_return current_time
      child = Child.create('photo' => uploadable_photo, 'last_known_location' => 'London')

      child['current_photo_key'].should == 'photo-2010-01-20T171032'
    end

    it "should have current_photo_key as photo attachment key on creation" do
      current_time = Time.parse("Jan 20 2010 17:10:32")
      Time.stub!(:now).and_return current_time
      child = Child.create('photo' => uploadable_photo, 'last_known_location' => 'London')

      child['_attachments'].should have_key('photo-2010-01-20T171032')
    end

    it "should only have one attachment on creation" do
      child = Child.create('photo' => uploadable_photo, 'last_known_location' => 'London')
      child['_attachments'].size.should == 1
    end

    it "should have data after creation" do
      current_time = Time.parse("Jan 20 2010 17:10:32")
      Time.stub!(:now).and_return current_time
      child = Child.create('photo' => uploadable_photo, 'last_known_location' => 'London')
      Child.get(child.id)['_attachments']['photo-2010-01-20T171032']['length'].should be > 0
    end

    it "should update current_photo_key on a photo change" do
      child = Child.create('photo' => uploadable_photo, 'last_known_location' => 'London')

      updated_at_time = Time.parse("Feb 20 2010 12:04:32")
      Time.stub!(:now).and_return updated_at_time
      child.update_attributes :photo => uploadable_photo_jeff

      child['current_photo_key'].should == 'photo-2010-02-20T120432'
    end

    it "should have updated current_photo_key as photo attachment key on a photo change" do
      child = Child.create('photo' => uploadable_photo, 'last_known_location' => 'London')

      updated_at_time = Time.parse("Feb 20 2010 12:04:32")
      Time.stub!(:now).and_return updated_at_time
      child.update_attributes :photo => uploadable_photo_jeff

      child['_attachments'].should have_key('photo-2010-02-20T120432')
    end

    it "should have photo data after a photo change" do
      child = Child.create('photo' => uploadable_photo, 'last_known_location' => 'London')

      updated_at_time = Time.parse("Feb 20 2010 12:04:32")
      Time.stub!(:now).and_return updated_at_time
      child.update_attributes :photo => uploadable_photo_jeff

      Child.get(child.id)['_attachments']['photo-2010-02-20T120432']['length'].should be > 0
    end

    it "should be able to read attachment after a photo change" do
      child = Child.create('photo' => uploadable_photo, 'last_known_location' => 'London')
      attachment = child.media_for_key(child['current_photo_key'])
      attachment.data.read.should == File.read(uploadable_photo.original_path)
    end
  end

  describe "audio attachment" do
    it "should create a field with recorded_audio on creation" do
      current_time = Time.parse("Jan 20 2010 17:10:32")
      Time.stub!(:now).and_return current_time
      child = Child.create('photo' => uploadable_photo, 'last_known_location' => 'London', 'audio' => uploadable_audio)

      child['recorded_audio'].should == 'audio-2010-01-20T171032'
    end

    it "should update recorded audio on a audio change" do
      child = Child.create('photo' => uploadable_photo, 'last_known_location' => 'London', 'audio' => uploadable_audio)

      updated_at_time = Time.parse("Feb 20 2010 12:04:32")
      Time.stub!(:now).and_return updated_at_time
      child.update_attributes :audio => uploadable_audio
      child['recorded_audio'].should == 'audio-2010-02-20T120432'
    end

  end

  describe "history log" do
    it "should not update history on initial creation of child document" do
      child = Child.create('last_known_location' => 'New York', 'photo' => uploadable_photo)

      child['histories'].should be_empty
    end

    it "should update history with 'from' value on last_known_location update" do
      child = Child.create('last_known_location' => 'New York', 'photo' => uploadable_photo)

      child['last_known_location'] = 'Philadelphia'
      child.save!

      changes = child['histories'].first['changes']
      changes['last_known_location']['from'].should == 'New York'
    end

    it "should update history with 'to' value on last_known_location update" do
      child = Child.create('last_known_location' => 'New York', 'photo' => uploadable_photo)

      child['last_known_location'] = 'Philadelphia'
      child.save!

      changes = child['histories'].first['changes']
      changes['last_known_location']['to'].should == 'Philadelphia'
    end

    it "should update history with 'from' value on age update" do
      child = Child.create('age' => '8', 'last_known_location' => 'New York', 'photo' => uploadable_photo)

      child['age'] = '6'
      child.save!

      changes = child['histories'].first['changes']
      changes['age']['from'].should == '8'
    end

    it "should update history with 'to' value on age update" do
      child = Child.create('age' => '8', 'last_known_location' => 'New York', 'photo' => uploadable_photo)

      child['age'] = '6'
      child.save!

      changes = child['histories'].first['changes']
      changes['age']['to'].should == '6'
    end

    it "should update history with a combined history record when multiple fields are updated" do
      child = Child.create('age' => '8', 'last_known_location' => 'New York', 'photo' => uploadable_photo)

      child['age'] = '6'
      child['last_known_location'] = 'Philadelphia'
      child.save!

      child['histories'].size.should == 1
      changes = child['histories'].first['changes']
      changes['age']['from'].should == '8'
      changes['age']['to'].should == '6'
      changes['last_known_location']['from'].should == 'New York'
      changes['last_known_location']['to'].should == 'Philadelphia'
    end

    it "should not record anything in the history if a save occured with no changes" do
      child = Child.create('photo' => uploadable_photo, 'last_known_location' => 'New York')

      loaded_child = Child.get(child.id)
      loaded_child.save!

      loaded_child['histories'].should be_empty
    end

    it "should not record empty string in the history if only change was spaces" do
      child = Child.create('origin' => '', 'photo' => uploadable_photo, 'last_known_location' => 'New York')

      child['origin'] = '    '
      child.save!

      child['histories'].should be_empty
    end

    it "should not record history on populated field if only change was spaces" do
      child = Child.create('last_known_location' => 'New York', 'photo' => uploadable_photo)

      child['last_known_location'] = ' New York   '
      child.save!

      child['histories'].should be_empty
    end

    it "should record history for newly populated field that previously was null" do
      # gender is the only field right now that is allowed to be nil when creating child document
      child = Child.create('gender' => nil, 'last_known_location' => 'London', 'photo' => uploadable_photo)

      child['gender'] = 'Male'
      child.save!

      child['histories'].first['changes']['gender']['from'].should be_nil
      child['histories'].first['changes']['gender']['to'].should == 'Male'
    end

    it "should apend latest history to the front of histories" do
      child = Child.create('last_known_location' => 'London', 'photo' => uploadable_photo)

      child['last_known_location'] = 'New York'
      child.save!

      child['last_known_location'] = 'Philadelphia'
      child.save!

      child['histories'].size.should == 2
      child['histories'][0]['changes']['last_known_location']['to'].should == 'Philadelphia'
      child['histories'][1]['changes']['last_known_location']['to'].should == 'New York'
    end

    it "should 'from' field with original current_photo_key on a photo addition" do
      updated_at_time = Time.parse("Jan 20 2010 12:04:24")
      Time.stub!(:now).and_return updated_at_time
      child = Child.create('photo' => uploadable_photo, 'last_known_location' => 'London')

      updated_at_time = Time.parse("Feb 20 2010 12:04:24")
      Time.stub!(:now).and_return updated_at_time
      child.update_attributes :photo => uploadable_photo_jeff

      changes = child['histories'].first['changes']
      changes['current_photo_key']['from'].should == "photo-2010-01-20T120424"
    end

    it "should 'to' field with new current_photo_key on a photo addition" do
      updated_at_time = Time.parse("Jan 20 2010 12:04:24")
      Time.stub!(:now).and_return updated_at_time
      child = Child.create('photo' => uploadable_photo, 'last_known_location' => 'London')

      updated_at_time = Time.parse("Feb 20 2010 12:04:24")
      Time.stub!(:now).and_return updated_at_time
      child.update_attributes :photo => uploadable_photo_jeff

      changes = child['histories'].first['changes']
      changes['current_photo_key']['to'].should == "photo-2010-02-20T120424"
    end

    it "should update history with username from last_updated_by" do
      child = Child.create('photo' => uploadable_photo, 'last_known_location' => 'London')

      child['last_known_location'] = 'Philadelphia'
      child['last_updated_by'] = 'some_user'
      child.save!

      child['histories'].first['user_name'].should == 'some_user'
    end

    it "should update history with the datetime from last_updated_at" do
      child = Child.create('photo' => uploadable_photo, 'last_known_location' => 'London')

      child['last_known_location'] = 'Philadelphia'
      child['last_updated_at'] = 'some_time'
      child.save!

      child['histories'].first['datetime'].should == 'some_time'
    end
  end
  
  describe ".has_one_interviewer?" do
    it "should be true if was created and not updated" do
      child = Child.create('last_known_location' => 'London', 'created_by' => 'john')
      
      child.has_one_interviewer?.should be_true
    end
    
    it "should be true if was created and updated by the same person" do
      child = Child.create('last_known_location' => 'London', 'created_by' => 'john')
      child['histories'] = [{"changes"=>{"gender"=>{"from"=>nil, "to"=>"Male"}, 
                                          "age"=>{"from"=>"1", "to"=>"15"}}, 
                                          "user_name"=>"john", 
                                          "datetime"=>"03/02/2011 21:48"}, 
                             {"changes"=>{"last_known_location"=>{"from"=>"Rio", "to"=>"Rio De Janeiro"}}, 
                                         "datetime"=>"03/02/2011 21:34", 
                                         "user_name"=>"john"}, 
                             {"changes"=>{"origin"=>{"from"=>"Rio", "to"=>"Rio De Janeiro"}}, 
                                          "user_name"=>"john", 
                                          "datetime"=>"03/02/2011 21:33"}]
      child['last_updated_by'] = 'john'
      
      child.has_one_interviewer?.should be_true
    end
    
    it "should be false if created by one person and updated by another" do
      child = Child.create('last_known_location' => 'London', 'created_by' => 'john')
      child['histories'] = [{"changes"=>{"gender"=>{"from"=>nil, "to"=>"Male"}, 
                                          "age"=>{"from"=>"1", "to"=>"15"}}, 
                                          "user_name"=>"jane", 
                                          "datetime"=>"03/02/2011 21:48"}, 
                             {"changes"=>{"last_known_location"=>{"from"=>"Rio", "to"=>"Rio De Janeiro"}}, 
                                         "datetime"=>"03/02/2011 21:34", 
                                         "user_name"=>"john"}, 
                             {"changes"=>{"origin"=>{"from"=>"Rio", "to"=>"Rio De Janeiro"}}, 
                                          "user_name"=>"john", 
                                          "datetime"=>"03/02/2011 21:33"}]
      child['last_updated_by'] = 'jane'
      
      child.has_one_interviewer?.should be_false
    end
    
  end

  describe "when fetching children" do
    before do
      Child.all.each { |child| child.destroy }
    end

    it "should return list of children ordered by name" do
      UUIDTools::UUID.stub("random_create").and_return(12345)

      Child.create('photo' => uploadable_photo, 'name' => 'Zbu', 'last_known_location' => 'POA')
      Child.create('photo' => uploadable_photo, 'name' => 'Abu', 'last_known_location' => 'POA')

      childrens = Child.all
      childrens.first['name'].should == 'Abu'
    end

    it "should order children with blank names first" do
      UUIDTools::UUID.stub("random_create").and_return(12345)


      Child.create('photo' => uploadable_photo, 'name' => 'Zbu', 'last_known_location' => 'POA')
      Child.create('photo' => uploadable_photo, 'name' => 'Abu', 'last_known_location' => 'POA')
      Child.create('photo' => uploadable_photo, 'name' => '', 'last_known_location' => 'POA')

      childrens = Child.all
      childrens.first['name'].should == ''
      childrens.size.should == 3
    end
  end

  describe ".photo" do
    it "should return nil if the record has no attached photo" do
      child = Child.new(:name=> "Bob McBobberson")
      child.photo.should be_nil
    end
  end
  
  describe ".audio" do
    it "should return nil if the recorded audio key is not an attachment" do
      child = Child.create('audio' => uploadable_audio)
      child["recorded_audio"] = "ThisIsNotAnAttachmentName"
      child.audio.should be_nil
    end
  end
  
  private
  
  def create_child(name)
    Child.create("name" => name, "last_known_location" => "new york")
  end 
  
  def stub_enabled_fields fields
      FormSection.stub!(:all_enabled_child_fields).and_return fields
  end

end
