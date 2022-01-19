# Import endpoint (aka Phenocode) information.
#
# Usage
# -----
# mix run import_endpoint_csv.exs \
#     <path-to-endpoint-definitions-file> \
#     <path-to-tagged-ordered-endpoints-file> \
#     <path-to-categories-file> \
#     <path-to-icd10fi>
#
# <path-to-endpoint-definitions-file>
#   Endpoint definition file in CSV format.
#   This file contains all endpoints:
#   - endpoints without any specific controls
#   - endpoints with specific controls
#
# <path-to-tagged-ordered-endpoints-file>
#   CSV file with header: TAG,CLASS,NAME
#   Provided by Aki.
#   It is used to get the main tag for each endpoint.
#
# <path-to-taglist-file>
#   CSV file with header: code,CHAPTER,OTHER
#   Provided by Aki.
#   It is used to map endpoints to categories.
#
# <path-to-icd10fi>
#   List of Finnish ICD-10, in CSV format and UTF-8.
#   Provided by Aki.
#   It is used to match an ICD-10 definition into a list of ICD-10s.
#   Must contain columns: CodeId, ParentId
#

alias Risteys.{Repo, Phenocode, PhenocodeIcd10, Icd10}
require Logger
import Ecto.Query

Logger.configure(level: :info)

# INPUT
Logger.info("Loading ICD-10 from files")

[
  endpoints_path,
  tagged_path,
  categories_path,
  icd10fi_file_path
] = System.argv()

# HELPERS
defmodule AssocICDs do
  def insert_or_update(registry, 10, phenocode, icds) do
    # Delete all previous associations of (Phenocode, Registry) -> ICD-10
    Repo.delete_all(
      from link in PhenocodeIcd10,
        where: link.phenocode_id == ^phenocode.id and link.registry == ^registry
    )

    # Add new associations
    Enum.each(icds, fn icd ->
      Logger.debug("Inserting: #{registry}, ICD-10, #{inspect(icd)}")
      icd_db = Repo.get_by!(Icd10, code: icd)

      case Repo.get_by(
             PhenocodeIcd10,
             registry: registry,
             phenocode_id: phenocode.id,
             icd10_id: icd_db.id
           ) do
        nil -> %PhenocodeIcd10{}
        existing -> existing
      end
      |> PhenocodeIcd10.changeset(%{
        registry: registry,
        phenocode_id: phenocode.id,
        icd10_id: icd_db.id
      })
      |> Repo.insert_or_update!()
    end)
  end
end

# Get meta information for endpoint processing
####
Logger.info("Pre-processing endpoint metadata files")

tags =
  tagged_path
  |> File.stream!()
  |> CSV.decode!(headers: true)
  |> Enum.reduce(%{}, fn %{"TAG" => tag, "NAME" => name}, acc ->
    Map.put(acc, name, tag)
  end)

categories =
  categories_path
  |> File.stream!()
  |> CSV.decode!(headers: true)
  |> Enum.reduce(%{}, fn %{"code" => tag, "CHAPTER" => chapter, "OTHER" => other}, acc ->
    category =
      if chapter != "" do
        chapter
      else
        other
      end

    Map.put(acc, tag, category)
  end)

{
  icd10s,
  map_undotted_dotted,
  map_child_parent,
  map_parent_children
} = Risteys.Icd10.init_parser(icd10fi_file_path)

# Clean-up & Transform endpoints
####
Logger.info("Cleaning-up endpoint from the definition files")

endpoints_path
|> File.stream!()
|> CSV.decode!(headers: true)

# Assert necessary columns are here and convert their names to atoms
|> Stream.map(fn row ->
  %{
    "NAME" => name,
    "TAGS" => tags,
    "LEVEL" => level,
    "OMIT" => omit,
    "LONGNAME" => longname,
    "SEX" => sex,
    "INCLUDE" => include,
    "PRE_CONDITIONS" => pre_conditions,
    "CONDITIONS" => conditions,
    "CONTROL_EXCLUDE" => control_exclude,
    "CONTROL_PRECONDITIONS" => control_preconditions,
    "CONTROL_CONDITIONS" => control_conditions,
    "OUTPAT_ICD" => outpat_icd,
    "HD_MAINONLY" => hd_mainonly,
    "HD_ICD_10_ATC" => hd_icd_10_atc,
    "HD_ICD_10" => hd_icd_10,
    "HD_ICD_9" => hd_icd_9,
    "HD_ICD_8" => hd_icd_8,
    "HD_ICD_10_EXCL" => hd_icd_10_excl,
    "HD_ICD_9_EXCL" => hd_icd_9_excl,
    "HD_ICD_8_EXCL" => hd_icd_8_excl,
    "COD_MAINONLY" => cod_mainonly,
    "COD_ICD_10" => cod_icd_10,
    "COD_ICD_9" => cod_icd_9,
    "COD_ICD_8" => cod_icd_8,
    "COD_ICD_10_EXCL" => cod_icd_10_excl,
    "COD_ICD_9_EXCL" => cod_icd_9_excl,
    "COD_ICD_8_EXCL" => cod_icd_8_excl,
    "OPER_NOM" => oper_nom,
    "OPER_HL" => oper_hl,
    "OPER_HP1" => oper_hp1,
    "OPER_HP2" => oper_hp2,
    "KELA_REIMB" => kela_reimb,
    "KELA_REIMB_ICD" => kela_reimb_icd,
    "KELA_ATC_NEEDOTHER" => kela_atc_needother,
    "KELA_ATC" => kela_atc,
    "KELA_VNRO_NEEDOTHER" => kela_vnro_needother,
    "KELA_VNRO" => kela_vnro,
    "CANC_TOPO" => canc_topo,
    "CANC_TOPO_EXCL" => canc_topo_excl,
    "CANC_MORPH" => canc_morph,
    "CANC_MORPH_EXCL" => canc_morph_excl,
    "CANC_BEHAV" => canc_behav,
    "Special" => special,
    "version" => version,
    "PARENT" => parent,
    "Latin" => latin
  } = row

  # Use atoms as map keys.
  # This prevents unexpectedly getting a nil on e.g. row["NAMe"]
  %{
    name: name,
    tags: tags,
    level: level,
    omit: omit,
    longname: longname,
    sex: sex,
    include: include,
    pre_conditions: pre_conditions,
    conditions: conditions,
    control_exclude: control_exclude,
    control_preconditions: control_preconditions,
    control_conditions: control_conditions,
    outpat_icd: outpat_icd,
    hd_mainonly: hd_mainonly,
    hd_icd_10_atc: hd_icd_10_atc,
    hd_icd_10: hd_icd_10,
    hd_icd_9: hd_icd_9,
    hd_icd_8: hd_icd_8,
    hd_icd_10_excl: hd_icd_10_excl,
    hd_icd_9_excl: hd_icd_9_excl,
    hd_icd_8_excl: hd_icd_8_excl,
    cod_mainonly: cod_mainonly,
    cod_icd_10: cod_icd_10,
    cod_icd_9: cod_icd_9,
    cod_icd_8: cod_icd_8,
    cod_icd_10_excl: cod_icd_10_excl,
    cod_icd_9_excl: cod_icd_9_excl,
    cod_icd_8_excl: cod_icd_8_excl,
    oper_nom: oper_nom,
    oper_hl: oper_hl,
    oper_hp1: oper_hp1,
    oper_hp2: oper_hp2,
    kela_reimb: kela_reimb,
    kela_reimb_icd: kela_reimb_icd,
    kela_atc_needother: kela_atc_needother,
    kela_atc: kela_atc,
    kela_vnro_needother: kela_vnro_needother,
    kela_vnro: kela_vnro,
    canc_topo: canc_topo,
    canc_topo_excl: canc_topo_excl,
    canc_morph: canc_morph,
    canc_morph_excl: canc_morph_excl,
    canc_behav: canc_behav,
    special: special,
    version: version,
    parent: parent,
    latin: latin
  }
end)

# Omit comment line
|> Stream.reject(fn %{name: name} -> String.starts_with?(name, "#") end)

# Replace NA values with nil
|> Stream.map(fn row ->
  Enum.reduce(row, %{}, fn {header, value}, acc ->
    value = if value == ["NA", ""], do: nil, else: value
    Map.put_new(acc, header, value)
  end)
end)

# Add endpoint category
|> Stream.map(fn row ->
  case Map.fetch(tags, row.name) do
    :error ->
      Map.put_new(row, :category, "Unknown")

    {:ok, tag} ->
      %{^tag => cat} = categories
      Map.put_new(row, :category, cat)
  end
end)

# Parse ICD-10: HD
|> Stream.map(fn row ->
  expanded =
    Risteys.Icd10.parse_rule(row.hd_icd_10, icd10s, map_child_parent, map_parent_children)

  Map.put_new(row, :hd_icd10s_exp, expanded)
end)

# Parse excl ICD-10: HD
|> Stream.map(fn row ->
  expanded =
    Risteys.Icd10.parse_rule(row.hd_icd_10_excl, icd10s, map_child_parent, map_parent_children)

  Map.put_new(row, :hd_icd10s_excl_exp, expanded)
end)

# Parse ICD-10: OUTPAT
|> Stream.map(fn %{hd_icd_10: hd} = row ->
  expanded =
    case row.outpat_icd do
      ^hd -> row.hd_icd10s_exp
      _ -> Risteys.Icd10.parse_rule(row.outpat_icd, icd10s, map_child_parent, map_parent_children)
    end

  Map.put_new(row, :outpat_icd10s_exp, expanded)
end)

# Parse ICD-10: COD
|> Stream.map(fn %{hd_icd_10: hd} = row ->
  expanded =
    case row.cod_icd_10 do
      ^hd -> row.hd_icd10s_exp
      _ -> Risteys.Icd10.parse_rule(row.cod_icd_10, icd10s, map_child_parent, map_parent_children)
    end

  Map.put_new(row, :cod_icd10s_exp, expanded)
end)

# Parse excl ICD-10: COD
|> Stream.map(fn row ->
  expanded =
    Risteys.Icd10.parse_rule(row.cod_icd_10_excl, icd10s, map_child_parent, map_parent_children)

  Map.put_new(row, :cod_icd10s_excl_exp, expanded)
end)

# Parse ICD-10: KELA
|> Stream.map(fn %{hd_icd_10: hd} = row ->
  expanded =
    case row.kela_reimb_icd do
      ^hd ->
        row.hd_icd10s_exp

      _ ->
        Risteys.Icd10.parse_rule(
          row.kela_reimb_icd,
          icd10s,
          map_child_parent,
          map_parent_children
        )
    end

  Map.put_new(row, :kela_icd10s_exp, expanded)
end)

# Convert ICD-10s to dotted notation
|> Stream.map(fn row ->
  dotted = %{
    outpat_icd10s_exp:
      Enum.map(row.outpat_icd10s_exp, &Risteys.Icd10.to_dotted(&1, map_undotted_dotted)),
    hd_icd10s_exp: Enum.map(row.hd_icd10s_exp, &Risteys.Icd10.to_dotted(&1, map_undotted_dotted)),
    hd_icd10s_excl_exp:
      Enum.map(row.hd_icd10s_excl_exp, &Risteys.Icd10.to_dotted(&1, map_undotted_dotted)),
    cod_icd10s_exp:
      Enum.map(row.cod_icd10s_exp, &Risteys.Icd10.to_dotted(&1, map_undotted_dotted)),
    cod_icd10s_excl_exp:
      Enum.map(row.cod_icd10s_excl_exp, &Risteys.Icd10.to_dotted(&1, map_undotted_dotted)),
    kela_icd10s_exp:
      Enum.map(row.kela_icd10s_exp, &Risteys.Icd10.to_dotted(&1, map_undotted_dotted))
  }

  Map.merge(row, dotted)
end)

# Inform about difficulty to parse CONDITIONS or CONTROL_CONDITIONS
|> Stream.each(fn row ->
  valid_conditions = is_nil(row.conditions) or not String.contains?(row.conditions, ["(", ")"])

  valid_control_conditions =
    is_nil(row.control_conditions) or not String.contains?(row.control_conditions, ["(", ")"])

  if not valid_conditions or not valid_control_conditions do
    Logger.warn(
      "Endpoint #{row.name} has 'conditions' or 'control_conditions' with '(' or ')': it will be incorrectly displayed."
    )
  end
end)

# Add endpoints to DB
####
|> Enum.each(fn row ->
  Logger.info("Inserting/updating: #{row.name}")

  phenocode =
    case Repo.get_by(Phenocode, name: row.name) do
      nil -> %Phenocode{}
      existing -> existing
    end
    |> Phenocode.changeset(%{
      name: row.name,
      tags: row.tags,
      level: row.level,
      omit: row.omit,
      longname: row.longname,
      sex: row.sex,
      include: row.include,
      pre_conditions: row.pre_conditions,
      conditions: row.conditions,
      control_exclude: row.control_exclude,
      control_preconditions: row.control_preconditions,
      control_conditions: row.control_conditions,
      outpat_icd: row.outpat_icd,
      hd_mainonly: row.hd_mainonly,
      hd_icd_10_atc: row.hd_icd_10_atc,
      hd_icd_10: row.hd_icd_10,
      hd_icd_9: row.hd_icd_9,
      hd_icd_8: row.hd_icd_8,
      hd_icd_10_excl: row.hd_icd_10_excl,
      hd_icd_9_excl: row.hd_icd_9_excl,
      hd_icd_8_excl: row.hd_icd_8_excl,
      cod_mainonly: row.cod_mainonly,
      cod_icd_10: row.cod_icd_10,
      cod_icd_9: row.cod_icd_9,
      cod_icd_8: row.cod_icd_8,
      cod_icd_10_excl: row.cod_icd_10_excl,
      cod_icd_9_excl: row.cod_icd_9_excl,
      cod_icd_8_excl: row.cod_icd_8_excl,
      oper_nom: row.oper_nom,
      oper_hl: row.oper_hl,
      oper_hp1: row.oper_hp1,
      oper_hp2: row.oper_hp2,
      kela_reimb: row.kela_reimb,
      kela_reimb_icd: row.kela_reimb_icd,
      kela_atc_needother: row.kela_atc_needother,
      kela_atc: row.kela_atc,
      kela_vnro_needother: row.kela_vnro_needother,
      kela_vnro: row.kela_vnro,
      canc_topo: row.canc_topo,
      canc_topo_excl: row.canc_topo_excl,
      canc_morph: row.canc_morph,
      canc_morph_excl: row.canc_morph_excl,
      canc_behav: row.canc_behav,
      special: row.special,
      version: row.version,
      parent: row.parent,
      latin: row.latin,
      category: row.category
    })
    |> Repo.insert_or_update!()

  AssocICDs.insert_or_update("OUTPAT", 10, phenocode, row.outpat_icd10s_exp)
  AssocICDs.insert_or_update("HD", 10, phenocode, row.hd_icd10s_exp)
  AssocICDs.insert_or_update("HD_EXCL", 10, phenocode, row.hd_icd10s_excl_exp)
  AssocICDs.insert_or_update("COD", 10, phenocode, row.cod_icd10s_exp)
  AssocICDs.insert_or_update("COD_EXCL", 10, phenocode, row.cod_icd10s_excl_exp)
  AssocICDs.insert_or_update("KELA", 10, phenocode, row.kela_icd10s_exp)
end)
