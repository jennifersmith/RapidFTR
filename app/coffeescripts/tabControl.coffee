class RapidFTR.tabControl
	init :->
		$(".tab").hide()
		$(".tab-handles li:first").addClass("current").show()
		$(".tab:first").show()  
		onClick = ->
			$(".tab-handles li").removeClass("current")
			$(".tab").hide()
			activeTab = $(this).attr("href")
			$(this).parent().addClass("current")
			$(activeTab).show()
			return false
		$(".tab-handles a").click(onClick);
