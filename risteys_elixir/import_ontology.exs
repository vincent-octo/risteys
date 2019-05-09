# Import ontology data into the database
#
# Usage:
#     mix run import_ontology.exs <json-file-ontology>
#
# where <json-file-ontology> is a JSON file containing ontology data
# with the following structure:
# {
#   "<endpoint-name>": {
#     {
#       "<ontology-name>": [val1, val2, ...],
#       ...
#     }
#   },
#   ...
# }
#
# The map data for each endpoint will be imported "as is" in a row
# cell in the database.

alias Risteys.{Repo, Phenocode}
import Ecto.Query
require Logger

Logger.configure(level: :info)
[filepath | _] = System.argv()

filepath
|> File.read!()
|> Jason.decode!()
|> Enum.each(fn {name, ontology} ->
  # Merge SNOMEDCT and SNOMED_CT values
  snomedct =
    ontology
    |> Map.get("SNOMEDCT_US_2018_03_01", [])
    |> MapSet.new()

  snomed_ct =
    ontology
    |> Map.get("SNOMED_CT_US_2018_03_01", [])
    |> MapSet.new()

  snomed =
    MapSet.union(snomedct, snomed_ct)
    |> Enum.to_list()

  # Remove ontology types we don't need
  keep_keys =
    ontology
    |> Map.keys()
    |> MapSet.new()
    |> MapSet.intersection(Phenocode.allowed_ontology_types())

  current_keys =
    ontology
    |> Map.keys()
    |> MapSet.new()

  remove_keys = MapSet.difference(current_keys, keep_keys)
  ontology = Map.drop(ontology, remove_keys)

  # Add SNOMED into the ontology
  ontology =
    if "SNOMEDCT_US_2018_03_01" in current_keys or "SNOMED_CT_US_2018_03_01" in current_keys do
      Logger.debug("got SNOMED data")
      Map.put(ontology, "SNOMED", snomed)
    end

  Repo.one(from p in Phenocode, where: p.name == ^name)
  |> Ecto.Changeset.change(ontology: ontology)
  |> Repo.update!()
end)