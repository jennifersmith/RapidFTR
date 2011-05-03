#RapidFTR.tabControl = function() {
#  $(".tab").hide();
#  $(".tab-handles li:first").addClass("current").show();
#  $(".tab:first").show();
#
#  $(".tab-handles a").click(function() {
#
#    $(".tab-handles li").removeClass("current");
#    $(".tab").hide();
#
#    var activeTab = $(this).attr("href");
#
#    $(this).parent().addClass("current");
#    $(activeTab).show();
#
#    return false;
#  });
#}
