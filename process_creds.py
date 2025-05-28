from openad.helpers import credentials
import glob, os, json, pickle
from openad import OpenadAPI
import jwt, time

MODEL_DEFAULT_MASTER = {
    "bmfm": "bmfm",
    "bmfm-mammal": "bmfm_pm",
    "bmfm-small-molecules": "bmfm_sm",
    "generation": "gen",
    "moler": "moler",
    "molformer": "molf",
    "pfas": "pfas",
    "properties": "prop",
    "smi-ted": "smi",
    "bi-aa-binding": "bi",
}
PROXY_URL = "https://open.accelerate.science/proxy"


def extract_creds():
    creds = {}
    for file in glob.glob(os.path.expanduser("~/.openad/*.cred")):
        creds[os.path.basename(file).split("_")[0]] = credentials.load_credentials(file)
    with open("cred_dump.json", "w", encoding="utf-8") as handle:
        json.dump(creds, handle)
    return


def assign_dict_value(input_dict: dict, path: str, value) -> dict:
    "assigns a value to a defined path in a dictionary"
    output_dict = input_dict.copy()
    statement = "exec('output_dict"
    for key in path.split(":"):
        statement = f'{statement}["{key}"]'
    if isinstance(value, (str)):
        statement = statement + f'="{value}"'
    else:
        statement = statement + f"={value}"
    eval(statement + "')", {"output_dict": output_dict})  # pylint:  disable=eval-used
    return output_dict


def place_creds():
    print("setting up credentials")
    openad_app = OpenadAPI()

    if os.path.exists("/run/secrets/openad_creds"):
        with open("/run/secrets/openad_creds", "r", encoding="utf-8") as handle:
            creds = json.load(handle)
    elif os.environ.get("OPENAD_CREDS") is not None:
        creds = json.loads(os.environ.get("OPENAD_CREDS"))
    else:
        return

    for cred in creds:
        new_credentials = credentials.DEFAULT_CREDENTIALS.copy()

        for item in creds[cred]:
            new_credentials[item] = creds[cred][item]
        if cred == "rxn":
            openad_app.request("add toolkit rxn")
        if cred == "deepsearch":
            openad_app.request("add toolkit ds4sd")

        credentials.write_credentials(new_credentials, os.path.expanduser(f"~/.openad/{cred}_api.cred"))
        print(f"credentials for {cred} added")
        openad_app.request("unset context")
    return


def show_creds():
    creds = {}
    for file in glob.glob(os.path.expanduser("~/.openad/*.cred")):
        creds[os.path.basename(file).split("_")[0]] = credentials.load_credentials(file)
    print(creds)


def place_models():
    print(" setting up models for the services")
    openad_app = OpenadAPI()

    if os.environ.get("OPENAD_MODEL_ALIAS") is not None:
        aliases = os.environ.get("OPENAD_MODEL_ALIAS")
    else:
        aliases = MODEL_DEFAULT_MASTER

    if os.environ.get("OPENAD_AUTH") is not None:
        bearer = os.environ.get("OPENAD_AUTH")
    elif os.environ.get("PROXY_KEY") is not None:
        bearer = os.environ.get("PROXY_KEY")
    else:
        bearer = None
    if bearer is not None:
        try:
            decoded_token = jwt.decode(
                bearer, options={"verify_at_hash": False, "verify_signature": False}, verify=False
            )
        except:
            print("invalid models token")
            return
        expiry_time = decoded_token["exp"]
        models = decoded_token["scp"]
        if os.environ.get("PROXY_URL") is not None:
            host = os.environ.get("PROXY_URL")
        else:
            host = PROXY_URL
        # Convert expiry time to a human-readable format
        expiry_datetime = time.strftime("%a %b %e, %G  at %R", time.localtime(expiry_time))

        print("remove group")
        for model in models:
            if model in aliases.keys():
                print(f"uncatalog service {aliases[model]}")
                x = openad_app.request(f"uncatalog model service   {aliases[model]} ")
                 
        x = openad_app.request("model auth remove group default ")
        print("Add group")
        x = openad_app.request(f"model auth add group default with '{bearer}' ")
        for model in models:
            if model in aliases.keys():
                print(f"catalog service  {aliases[model]}")
                x = openad_app.request(
                    f"catalog model service from remote '{host}' as  {aliases[model]}  USING (Inference-Service={model}  auth_group=default )"
                )
                print("loaded model :" + model)
        return
    elif os.path.exists("/run/secrets/openad_models"):

        with open("/run/secrets/openad_models", "r", encoding="utf-8") as handle:
            models = json.load(handle)

    elif os.environ.get("OPENAD_MODELS") is not None:
        models = json.loads(os.environ.get("OPENAD_MODELS"))
    else:
        return

    if "auth_groups" in models:
        for group in models["auth_groups"]:
            x = openad_app.request(f"model auth add group {group} with '{models['auth_groups'][group]}' ")
            print("catalog model =  " + x)
    if "services" in models:
        for service in models["services"]:
            x = openad_app.request(
                f"catalog model service from remote '{models['services'][service]['host']}' as  {service}  USING (Inference-Service={models['services'][service]['inference-service']}  auth_group={models['services'][service]['auth_group']} )"
            )


if __name__ == "__main__":
    place_creds()
    place_models()
