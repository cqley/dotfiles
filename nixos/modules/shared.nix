{ ... }: {
  services.syncthing = {
    enable = true;
    user = "cat";
    dataDir = "/home/cat/";
    configDir = "/home/cat/.config/syncthing";
    overrideDevices = true;
    overrideFolders = true;
    settings = {
      devices = {
        "box" = { id = "2M2B2UF-QRHLUFR-SFDCSFC-LU2V4BR-UAWA24J-7SNNFOK-H5WDAIV-X4AT3QY"; };
        "bed" = { id = "HYGBY4A-MQBNOTJ-HDMRQ7K-YQZK3UC-UD2KEDH-TNTZMXE-67DWKQV-UTMFOA6"; };
      };
      folders = {
        "air" = {
          path = "/home/cat/shared";
          devices = [ "box" "bed" ];
        };
      };
    };
  };
}
