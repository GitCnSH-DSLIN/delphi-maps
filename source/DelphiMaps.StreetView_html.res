        ��  ��                    <   ��
 S T R E E T V I E W _ H T M L       0         <!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml">
    <head>
        <meta http-equiv="content-type" content="text/html; charset=utf-8"/>
        <title>Abf Viewer: Embedded StreetView</title>
        <script src="http://maps.google.com/maps/api/js?sensor=false" type="text/javascript"></script>
        <script type="text/javascript">
          var geocoder;
          var StreetView1;

          function initialize()
          {
            var startPos = new google.maps.LatLng(37.869260, -122.254811);
            var panoramaOptions = {
              position:startPos,
              pov: {
                heading: 180,
                pitch:0,
                zoom:1
              }
            }
            StreetView1 = new google.maps.StreetViewPanorama(document.getElementById("StreetViewDiv"), panoramaOptions);
            StreetView1.setVisible(true);

            geocoder = new google.maps.Geocoder();
          }

          function AddressToLatLng(address)
          {
            if (!geocoder)
              return null;

            geocoder.geocode(
              { 'address': address },
              function(results,status)
              {
                if (status == google.maps.GeocoderStatus.OK)
                {
                  return (results[0].geometry.location);
                }
                else
                {
                  alert("Geocode was not successful for the following reason: " + status);
                }
              }
            );
          }

        </script>
    </head>
    <body onload="initialize()" style="margin:0;padding:0">
        <div id="StreetViewDiv" style="width:100%;height:276px;margin:0;padding:0"></div>
    </body>
</html>
   