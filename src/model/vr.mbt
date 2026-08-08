///|
pub(all) enum Vr {
  AE
  AS
  AT
  CS
  DA
  DS
  DT
  FL
  FD
  IS
  LO
  LT
  OB
  OD
  OF
  OL
  OV
  OW
  PN
  SH
  SL
  SQ
  SS
  ST
  SV
  TM
  UC
  UI
  UL
  UN
  UR
  US
  UT
  UV
} derive(Eq, Debug)

///|
pub fn Vr::from_string(value : String) -> Vr? {
  match value {
    "AE" => Some(AE)
    "AS" => Some(AS)
    "AT" => Some(AT)
    "CS" => Some(CS)
    "DA" => Some(DA)
    "DS" => Some(DS)
    "DT" => Some(DT)
    "FL" => Some(FL)
    "FD" => Some(FD)
    "IS" => Some(IS)
    "LO" => Some(LO)
    "LT" => Some(LT)
    "OB" => Some(OB)
    "OD" => Some(OD)
    "OF" => Some(OF)
    "OL" => Some(OL)
    "OV" => Some(OV)
    "OW" => Some(OW)
    "PN" => Some(PN)
    "SH" => Some(SH)
    "SL" => Some(SL)
    "SQ" => Some(SQ)
    "SS" => Some(SS)
    "ST" => Some(ST)
    "SV" => Some(SV)
    "TM" => Some(TM)
    "UC" => Some(UC)
    "UI" => Some(UI)
    "UL" => Some(UL)
    "UN" => Some(UN)
    "UR" => Some(UR)
    "US" => Some(US)
    "UT" => Some(UT)
    "UV" => Some(UV)
    _ => None
  }
}

///|
pub fn Vr::to_string(self : Vr) -> String {
  match self {
    AE => "AE"
    AS => "AS"
    AT => "AT"
    CS => "CS"
    DA => "DA"
    DS => "DS"
    DT => "DT"
    FL => "FL"
    FD => "FD"
    IS => "IS"
    LO => "LO"
    LT => "LT"
    OB => "OB"
    OD => "OD"
    OF => "OF"
    OL => "OL"
    OV => "OV"
    OW => "OW"
    PN => "PN"
    SH => "SH"
    SL => "SL"
    SQ => "SQ"
    SS => "SS"
    ST => "ST"
    SV => "SV"
    TM => "TM"
    UC => "UC"
    UI => "UI"
    UL => "UL"
    UN => "UN"
    UR => "UR"
    US => "US"
    UT => "UT"
    UV => "UV"
  }
}

///|
pub fn Vr::uses_u32_length(self : Vr) -> Bool {
  match self {
    OB | OD | OF | OL | OV | OW | SQ | UC | UN | UR | UT => true
    _ => false
  }
}

///|
pub fn Vr::is_text(self : Vr) -> Bool {
  match self {
    AE
    | AS
    | CS
    | DA
    | DS
    | DT
    | IS
    | LO
    | LT
    | PN
    | SH
    | ST
    | TM
    | UC
    | UI
    | UR
    | UT => true
    _ => false
  }
}
