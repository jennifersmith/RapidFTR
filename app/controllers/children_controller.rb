class ChildrenController < ApplicationController
  skip_before_filter :verify_authenticity_token

  # GET /children
  # GET /children.xml
  def index
    @page_name = "Listing children"
    @children = Child.all
    @aside = 'shared/sidebar_links'
    
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @children }
      format.csv  do
				export_generator = ExportGenerator.new @children
				csv_export = export_generator.to_csv
    		send_export(csv_export)
			end
      format.json { render :json => @children }
      format.pdf do
        pdf_data = ExportGenerator.new(@children).to_full_pdf
        send_export pdf_data
      end
    end
  end

  # GET /children/1
  # GET /children/1.xml
  def show
    @child = Child.get(params[:id])
    @user = User.find_by_user_name(current_user_name)

    @form_sections = FormSection.enabled_by_order

    @page_name = @child

    @aside = 'picture'
    @body_class = 'profile-page'

    respond_to do |format|
      format.html do
      if @child.nil?
      flash[:error] = "Child with the given id is not found"
      redirect_to :action => :index and return
      end
      end
      format.xml  { render :xml => @child }
      format.json { render :json => @child.to_json }
      format.csv do
        export_generator = ExportGenerator.new [@child]
				csv_export = export_generator.to_csv
    		send_export(csv_export)
      end
      format.pdf do
        pdf_data = ExportGenerator.new(@child).to_full_pdf
        send_export pdf_data
      end
    end
  end

  # GET /children/new
  # GET /children/new.xml
  def new
    @page_name = "New child record"
    @child = Child.new
    @form_sections = FormSection.enabled_by_order
    respond_to do |format|
      format.html
      format.xml  { render :xml => @child }
    end
  end

  # GET /children/1/edit
  def edit
    @page_name = "Edit child record"
    @child = Child.get(params[:id])
    @form_sections = FormSection.enabled_by_order
  end

  # POST /children
  # POST /children.xml
  def create
    @child = Child.new_with_user_name(current_user_name, params[:child])
    respond_to do |format|
      if @child.save
        flash[:notice] = 'Child record successfully created.'
        format.html { redirect_to(@child) }
        format.xml  { render :xml => @child, :status => :created, :location => @child }
        format.json { render :json => @child.to_json }
      else
        format.html {
          @form_sections = FormSection.enabled_by_order
          render :action => "new"
        }
        format.xml  { render :xml => @child.errors, :status => :unprocessable_entity }
      end
    end
  end

  def edit_photo
    @child = Child.get(params[:id])
    @page_name = "Edit Photo"
  end

  def update_photo
    @child = Child.get(params[:id])
    orientation = params[:child].delete(:photo_orientation).to_i
    if orientation != 0
      @child.rotate_photo(orientation)
      @child.set_updated_fields_for current_user_name
      @child.save
    end
    redirect_to(@child)
  end


  def new_search

  end

  # PUT /children/1
  # PUT /children/1.xml
  def update
    @child = Child.get(params[:id]) || Child.new_with_user_name(current_user_name, params[:child])
    new_photo = params[:child].delete(:photo)
    new_audio = params[:child].delete(:audio)
    @child.update_properties_with_user_name(current_user_name, new_photo, params[:delete_child_photo], new_audio, params[:child])

    respond_to do |format|
      if @child.save
        flash[:notice] = 'Child was successfully updated.'
        format.html { redirect_to(@child) }
        format.xml  { head :ok }
        format.json { render :json => @child.to_json }
      else
        format.html {
          @form_sections = FormSection.enabled_by_order
          render :action => "edit"
        }
        format.xml  { render :xml => @child.errors, :status => :unprocessable_entity }
      end
    end
	end

	# DELETE /children/1
	# DELETE /children/1.xml
	def destroy
		@child = Child.get(params[:id])
		@child.destroy

		respond_to do |format|
			format.html { redirect_to(children_url) }
			format.xml  { head :ok }
			format.json { render :json => {:response => "ok"}.to_json }
		end
	end

	def search
		@page_name = "Child Search"
		@aside = "shared/sidebar_links"
		if (params[:query])
			@search = Search.new(params[:query]) 
			if @search.valid?    
				@results = Child.search(@search)
				@highlighted_fields = FormSection.sorted_highlighted_fields.map do |field|
					{ :name => field.name, :display_name => field.display_name }
				end
			else
				render :search
			end
		end
		respond_to do |format|
			format.html do
				if @results && @results.length == 1
					redirect_to child_path( @results.first )
				end
			end
			format.csv do
				export_generator = ExportGenerator.new @results
				csv_export = export_generator.to_csv
				send_export(csv_export)
			end
		end
	end
	def export_photo_to_pdf
		child = Child.get(params[:id])
		pdf_data = ExportGenerator.new(child).to_photowall_pdf
		send_export(pdf_data)
	end

	def export_data
		selected_records = params["selections"] || {}
		if selected_records.empty?
			raise ErrorResponse.bad_request('You must select at least one record to be exported')
		end

		children = selected_records.sort.map{ |index, child_id| Child.get(child_id) }
		export_generator = ExportGenerator.new children

		if params[:commit] == "Export to Photo Wall"
			export = export_generator.to_photowall_pdf
		elsif params[:commit] == "Export to PDF"
			export = export_generator.to_full_pdf
		elsif params[:commit] == "Export to CSV"
			export = export_generator.to_csv
		end

		send_export export
	end

	private

	def send_export(export) 
		send_data export.data, export.options 
	end

end
