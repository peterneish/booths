var map, pointarray, heatmap;
var heatmaps = {};
var defaultzoom = 4;
var defaultcentre = new google.maps.LatLng(-28.75,133.70);
var booths_loaded = false;


function initialize() {
  var mapOptions = {
    zoom: defaultzoom,
    center: defaultcentre,
    mapTypeId: google.maps.MapTypeId.ROADMAP
  };

  map = new google.maps.Map(document.getElementById('map-canvas'),
      mapOptions);
	  
  manager = new MarkerManager(map);
  infowindow = new google.maps.InfoWindow({ content: "holding..."});


  loadParty("ALP", true);
  loadParty("DLP");
  loadParty("FFP");
  loadParty("GRN");
  loadParty("LP");
  loadParty("LNP");
  loadParty("NP");
  loadParty("ON");
  loadParty("PUP");
  loadParty("RUA");
  loadParty("ASXP");


  toggleHeatmapParty("ALP");

  $("ul.partychange a").click(function(){
	  toggleHeatmapParty($(this).attr("data-party"));
	  $('ul.partychange li').removeClass('active');
	  $(this).parent('li').addClass('active');
	  // and add the label
	  $('#partylabel').text($(this).text());
	  
   });
   
   $('#title').click(function(){
		revertMap();
	});	
	
	$('.moreinfo').click(function(){
		toggleInfo();
	});
	
  
   //loadBooths();
   // we'll now only load if we zoom in far enough
   google.maps.event.addListener(map, 'zoom_changed', loadBooths);



}

function loadParty(party, show){
  $(".spinner").show();

  if(!party) return;

  var data = $.getJSON('./data/' + party + '.json', function(json) {

	var partydata = [];

	for (var i=0; i < json.data.length; i++){
		if(json.data[i].count > 0){
			var line = {location: new google.maps.LatLng( json.data[i].lat, json.data[i].lng), weight: json.data[i].count}	;
			partydata.push(line);	
		}
	}

	
	  var gradient = [
    'rgba(0, 255, 255, 0)',
    'rgba(0, 255, 255, 1)',
    'rgba(0, 127, 255, 1)',
    'rgba(0, 63, 255, 1)',
    'rgba(0, 0, 255, 1)',
    'rgba(0, 0, 191, 1)',
    'rgba(0, 0, 159, 1)',
    'rgba(0, 0, 127, 1)',
    'rgba(127, 0, 63, 1)',
    'rgba(191, 0, 31, 1)',
    'rgba(255, 0, 0, 1)'
  ];
  

  
  
	heatmaps[party] = new google.maps.visualization.HeatmapLayer({
	   data: partydata ,
       opactity: 0.9,
	   maxIntensity: json.max,
	   radius: 20,
	   gradient: gradient,
	   dissipating: true 
	});

	if(show){
		heatmaps[party].setMap(map);
	}
	
	$(".spinner").hide();
	
  });
}

function revertMap(){
	map.setZoom(defaultzoom);
	map.setCenter(defaultcentre);
}


function toggleHeatmapParty(party){

	  $.each(heatmaps, function(key, value){
		if (key == party){
			value.setMap(map);
		}
		else{
			value.setMap(null);
		}
	  });
}

    //console.log("zoom changed");
function loadBooths(){

	// only fetch the markers if we haven't already
    if(map.getZoom() > 10 && !booths_loaded){
		$.getJSON("./data/booths.json", function(results){
		for (var i = 0; i < results.features.length; i++) {
		
			// build the html from the candidates properties
			var whtml =  "<h3>"+ results.features[i].name + "</h3>";

			if(results.features[i].res){
				for (var x=0; x < results.features[i].res.length; x++){
					whtml+= "<p>" + results.features[i].res[x] + "</p>";		
				}
			}

			var coords = results.features[i].coord;
			var latLng = new google.maps.LatLng(coords[0], coords[1]);
				var marker = new google.maps.Marker({
					position: latLng,
					title : results.features[i].name,
					html : whtml
				});
			google.maps.event.addListener(marker, 'click', function(){
				infowindow.setContent(this.html);
				infowindow.open(map, this);
			});

			manager.addMarker(marker, 13);

		} 			
		manager.refresh();
		});	
		booths_loaded = true;
	}
}

google.maps.event.addDomListener(window, 'load', initialize);
