defmodule Properties.Property do
  use Ecto.Schema
  import Ecto.Query

  @optional_fields [:tax_rate_cd, :house_number_high, :house_number_low,
                    :street_direction, :street, :street_type, :last_assessment_year,
                    :last_assessment_amount, :building_area, :year_built,
                    :number_of_bedrooms, :number_of_bathrooms,
                    :number_of_powder_rooms, :lot_area, :zoning, :building_type,
                    :zip_code, :geom, :air_conditioning, :fireplace, :parking_type,
                    :number_units]

  schema "properties" do
    field :tax_key, :string
    field :tax_rate_cd, :integer
    field :house_number_high, :string
    field :house_number_low, :string
    field :street_direction, :string
    field :street, :string
    field :street_type, :string
    field :last_assessment_year, :integer
    field :last_assessment_amount, :integer
    field :building_area, :integer
    field :year_built, :integer
    field :number_of_bedrooms, :integer
    field :number_of_bathrooms, :integer
    field :number_of_powder_rooms, :integer
    field :lot_area, :integer
    field :zoning, :string
    field :building_type, :string
    field :zip_code, :string
    field :land_use, :string
    field :land_use_general, :string
    field :fireplace, :integer
    field :air_conditioning, :integer
    field :parking_type, :string
    field :number_units, :integer
    field :geom, Geo.Point
    field :distance, :float, virtual: true

    timestamps
  end

  def changeset(model, params) do
    model
    |> Ecto.Changeset.cast(params, [:tax_key] ++ @optional_fields)
    |> Ecto.Changeset.validate_required([:tax_key])
    |> Ecto.Changeset.unique_constraint(:tax_key, name: :properties_tax_key_index)
  end

  def address(property) do
    zip_code = String.slice(property.zip_code, 0, 5)
    "#{property.house_number_low} #{property.street_direction} #{property.street} #{street_type(property.street_type)}, Milwaukee, WI #{zip_code}"
  end

  def street_type("TR"), do: "TERRACE"
  def street_type("CR"), do: "CIRCLE"
  def street_type("AV"), do: "AVENUE"
  def street_type("ST"), do: "STREET"
  def street_type(type), do: type

  def within(query, point, radius_in_m) do
    {lng, lat} = point.coordinates
    from(property in query, where: fragment("ST_DWithin(?::geography, ST_SetSRID(ST_MakePoint(?, ?), ?), ?)", property.geom, ^lng, ^lat, ^point.srid, ^radius_in_m))
  end

  def order_by_nearest(query, point) do
    {lng, lat} = point.coordinates
    from(property in query, order_by: fragment("? <-> ST_SetSRID(ST_MakePoint(?,?), ?)", property.geom, ^lng, ^lat, ^point.srid))
  end

  def select_with_distance(query, point) do
    {lng, lat} = point.coordinates
    from(property in query,
         select: %{property | distance: fragment("ST_Distance_Sphere(?, ST_SetSRID(ST_MakePoint(?,?), ?))", property.geom, ^lng, ^lat, ^point.srid)})
  end

  def filter_by_bathrooms(query, min_bathrooms, max_bathrooms) do
    from(p in query,
       where: fragment("(? + (coalesce(?, 0) * 0.5)) >= ?", p.number_of_bathrooms, p.number_of_powder_rooms, ^min_bathrooms) and
       fragment("(? + (coalesce(?, 0) * 0.5)) <= ?", p.number_of_bathrooms, p.number_of_powder_rooms, ^max_bathrooms))
  end

  def filter_by_bedrooms(query, min_bedrooms, max_bedrooms) do
    from(p in query,
       where: p.number_of_bedrooms >= ^min_bedrooms and
       p.number_of_bedrooms <= ^max_bedrooms
     )
  end

  def filter_by_zipcode(query, nil), do: query
  def filter_by_zipcode(query, ""), do: query
  def filter_by_zipcode(query, zipcode) do
    from(p in query,
       where: fragment("substring(?, 0, 6) = ?", p.zip_code, ^zipcode)
     )
  end

  def maybe_filter_by(query, _field, nil), do: query
  def maybe_filter_by(query, _field, ""), do: query
  def maybe_filter_by(query, field, value) do
    from(p in query,
       where: field(p, ^field) == ^value
     )
  end
end

# import Ecto.Query; from(i in MilwaukeeProperties.Property, where: fragment("substring(?, 0, 6)", i.zip_code) == "53207" and i.land_use == "8810" and is_nil(i.geom)) |> MilwaukeeProperties.Repo.all |> Enum.each(fn(p) -> :timer.sleep(100); MilwaukeeProperties.LocationService.update_property_with_geom(p) end)