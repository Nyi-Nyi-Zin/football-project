package usecase

import "testing"

func TestValidateStake(t *testing.T) {
	tests := []struct {
		name  string
		stake float64
		valid bool
	}{
		{name: "minimum", stake: MinimumStakeMMK, valid: true},
		{name: "maximum", stake: MaximumStakeMMK, valid: true},
		{name: "below minimum", stake: MinimumStakeMMK - 1, valid: false},
		{name: "above maximum", stake: MaximumStakeMMK + 1, valid: false},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			err := validateStake(test.stake)
			if test.valid && err != nil {
				t.Fatalf("expected stake to be valid, got %v", err)
			}
			if !test.valid && err == nil {
				t.Fatal("expected stake validation error")
			}
		})
	}
}

func TestValidatePayout(t *testing.T) {
	if err := validatePayout(MaximumPayoutMMK); err != nil {
		t.Fatalf("expected maximum payout to be valid, got %v", err)
	}
	if err := validatePayout(MaximumPayoutMMK + 0.01); err == nil {
		t.Fatal("expected payout above cap to be rejected")
	}
}
