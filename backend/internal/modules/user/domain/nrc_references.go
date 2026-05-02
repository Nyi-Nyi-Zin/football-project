package domain

// NRCRegion represents a region/state in Myanmar
type NRCRegion struct {
	ID      int    `json:"id" gorm:"primaryKey;autoIncrement"`
	Code    string `json:"code" gorm:"size:10;not null;uniqueIndex"`
	NameEn  string `json:"name_en" gorm:"size:100"`
	NameMm  string `json:"name_mm" gorm:"size:100"`
}

func (NRCRegion) TableName() string {
	return "users.nrc_regions"
}

// NRCTownship represents a township in Myanmar
type NRCTownship struct {
	ID       int    `json:"id" gorm:"primaryKey;autoIncrement"`
	NrcCode  string `json:"nrc_code" gorm:"size:10;not null"`
	NameEn   string `json:"name_en" gorm:"size:100"`
	NameMm   string `json:"name_mm" gorm:"size:100"`
	RegionID int    `json:"region_id" gorm:"column:region_id"`
}

func (NRCTownship) TableName() string {
	return "users.nrc_townships"
}

// NRCType represents an NRC type/category
type NRCType struct {
	ID     int    `json:"id" gorm:"primaryKey;autoIncrement"`
	Code   string `json:"code" gorm:"size:10;not null;uniqueIndex"`
	NameMm string `json:"name_mm" gorm:"size:20"`
}

func (NRCType) TableName() string {
	return "users.nrc_types"
}
