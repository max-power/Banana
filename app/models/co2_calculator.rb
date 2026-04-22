class Co2Calculator
  # Average EU emissions in g/km
  EMISSION_RATES = {
    small_petrol_car: 120,
    medium_petrol_car: 150,
    large_petrol_car: 180,
    small_diesel_car: 110,
    medium_diesel_car: 140,
    large_diesel_car: 170,
    hybrid_car: 90,
    electric_car: 0
  }.freeze

  def initialize(distance_km, car_type: :medium_petrol_car)
    @distance = distance_km || 0
    @emission_rate = EMISSION_RATES.fetch(car_type, EMISSION_RATES[:medium_petrol_car])
  end

  # Returns CO₂ produced in kg
  def calculate_emissions
    (@distance * @emission_rate) / 1000.0
  end

  # Class-level convenience method
  def self.call(distance, car_type: :medium_petrol_car)
    new(distance, car_type: car_type).calculate_emissions
  end
end
